package acceptance_test

import (
	"fmt"
	"strconv"
	"time"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
	"github.com/onsi/gomega/gexec"

	"brats/utils"
)

var _ = Describe("migration from the bosh postgres job to postgres-release", Label("postgres-release"), func() {
	const (
		deployTimeout = 20 * time.Minute
		sshTimeout    = 5 * time.Minute
		marker        = "brats_migration_marker"
	)

	var pgVersion int

	BeforeEach(func() {
		var err error
		pgVersion, err = strconv.Atoi(utils.LoadEnvOrDefault("PG_VERSION", strconv.Itoa(defaultPGVersion)))
		Expect(err).NotTo(HaveOccurred(), "PG_VERSION must be an integer")
		Expect(supportedPGVersions).To(ContainElement(pgVersion), "PG_VERSION must be one of %v", supportedPGVersions)
	})

	ssh := func(deploymentName, command string) string {
		session := utils.OuterBosh("-d", deploymentName, "ssh", "bosh/0", "-c", command)
		Eventually(session, sshTimeout).Should(gexec.Exit(0))
		return string(session.Out.Contents())
	}

	psql := func(deploymentName, pkg, sql string) string {
		return ssh(deploymentName, fmt.Sprintf(
			`sudo LD_LIBRARY_PATH=/var/vcap/packages/%[1]s/lib /var/vcap/packages/%[1]s/bin/psql -h 127.0.0.1 -p 5432 -U vcap -d bosh -tAc "%[2]s"`,
			pkg, sql,
		))
	}

	It("moves the data with migrate-to-postgres-release and keeps it", func() {
		deploymentName := fmt.Sprintf("postgres-migration-%d-%x", pgVersion, GinkgoT().RandomSeed())
		DeferCleanup(func() {
			if utils.SkipCleanup() {
				return
			}
			session := utils.OuterBosh("-n", "delete-deployment", "-d", deploymentName, "--force")
			Eventually(session, 10*time.Minute).Should(gexec.Exit(0))
		})

		By("deploying the bosh release's postgres job")
		session := utils.OuterBosh("deploy", "-n", utils.AssetPath("postgres-manifest.yml"),
			"-d", deploymentName,
			"-v", fmt.Sprintf("stemcell-os=%s", utils.StemcellOS()),
			"-v", fmt.Sprintf("deployment-name=%s", deploymentName),
		)
		Eventually(session, deployTimeout).Should(gexec.Exit(0))

		By("writing a marker row")
		psql(deploymentName, "postgres-15", fmt.Sprintf("CREATE TABLE %[1]s (v text); INSERT INTO %[1]s VALUES ('migrated')", marker))

		By("running migrate-to-postgres-release")
		Expect(ssh(deploymentName, "sudo /var/vcap/jobs/postgres/bin/migrate-to-postgres-release")).To(ContainSubstring("Done."))

		By(fmt.Sprintf("deploying postgres-release with PostgreSQL %d on the same instance group", pgVersion))
		session = utils.OuterBosh("deploy", "-n", utils.AssetPath("postgres-release-manifest.yml"),
			"-o", utils.AssetPath("op-postgres-release-on-bosh-instance-group.yml"),
			"-d", deploymentName,
			"-v", fmt.Sprintf("stemcell-os=%s", utils.StemcellOS()),
			"-v", fmt.Sprintf("deployment-name=%s", deploymentName),
			"-v", fmt.Sprintf("pg-version=%d", pgVersion),
		)
		Eventually(session, deployTimeout).Should(gexec.Exit(0))

		pkg := fmt.Sprintf("postgres-%d", pgVersion)
		By("checking the running major version")
		Expect(psql(deploymentName, pkg,
			"SELECT 'pgmajor=' || current_setting('server_version_num')::int / 10000",
		)).To(ContainSubstring(fmt.Sprintf("pgmajor=%d", pgVersion)))

		By("checking that the marker row survived the migration")
		Expect(psql(deploymentName, pkg, fmt.Sprintf("SELECT 'marker=' || v FROM %s", marker))).To(ContainSubstring("marker=migrated"))
	})
})
