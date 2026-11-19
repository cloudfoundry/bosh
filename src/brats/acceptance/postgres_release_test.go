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

var supportedPGVersions = []int{15, 16, 17, 18}

const defaultPGVersion = 15

var _ = Describe("postgres-release", Label("postgres-release"), func() {
	const (
		deployTimeout = 20 * time.Minute
		sshTimeout    = 2 * time.Minute
		upgradeMarker = "brats_upgrade_marker"
	)

	manifest := utils.AssetPath("postgres-release-manifest.yml")

	var pgVersion int

	BeforeEach(func() {
		var err error
		pgVersion, err = strconv.Atoi(utils.LoadEnvOrDefault("PG_VERSION", strconv.Itoa(defaultPGVersion)))
		Expect(err).NotTo(HaveOccurred(), "PG_VERSION must be an integer")
		Expect(supportedPGVersions).To(ContainElement(pgVersion), "PG_VERSION must be one of %v", supportedPGVersions)
	})

	deploy := func(deploymentName string, version int) {
		By(fmt.Sprintf("deploying %s with PostgreSQL %d", deploymentName, version))
		session := utils.OuterBosh("deploy", "-n", manifest,
			"-d", deploymentName,
			"-v", fmt.Sprintf("stemcell-os=%s", utils.StemcellOS()),
			"-v", fmt.Sprintf("deployment-name=%s", deploymentName),
			"-v", fmt.Sprintf("pg-version=%d", version),
		)
		Eventually(session, deployTimeout).Should(gexec.Exit(0))
	}

	psql := func(deploymentName string, version int, sql string) string {
		pkg := fmt.Sprintf("/var/vcap/packages/postgres-%d", version)
		session := utils.OuterBosh("-d", deploymentName, "ssh", "postgres/0", "-c",
			fmt.Sprintf(`sudo LD_LIBRARY_PATH=%[1]s/lib %[1]s/bin/psql -h 127.0.0.1 -p 5432 -U vcap -d bosh -tAc "%[2]s"`, pkg, sql),
		)
		Eventually(session, sshTimeout).Should(gexec.Exit(0))
		return string(session.Out.Contents())
	}

	expectRunningMajorVersion := func(deploymentName string, version int) {
		By(fmt.Sprintf("checking that %s runs PostgreSQL %d", deploymentName, version))
		Expect(psql(deploymentName, version,
			"SELECT 'pgmajor=' || current_setting('server_version_num')::int / 10000",
		)).To(ContainSubstring(fmt.Sprintf("pgmajor=%d", version)))
	}

	deleteDeploymentOnCleanup := func(deploymentName string) {
		DeferCleanup(func() {
			if utils.SkipCleanup() {
				return
			}
			session := utils.OuterBosh("-n", "delete-deployment", "-d", deploymentName, "--force")
			Eventually(session, 10*time.Minute).Should(gexec.Exit(0))
		})
	}

	It("deploys the selected PostgreSQL version", func() {
		deploymentName := fmt.Sprintf("postgres-release-%d-%x", pgVersion, GinkgoT().RandomSeed())
		deleteDeploymentOnCleanup(deploymentName)

		deploy(deploymentName, pgVersion)
		expectRunningMajorVersion(deploymentName, pgVersion)
	})

	It("upgrades from the previous PostgreSQL version and keeps the data", func() {
		if pgVersion == supportedPGVersions[0] {
			Skip(fmt.Sprintf("PostgreSQL %d is the oldest supported version; there is nothing to upgrade from", pgVersion))
		}
		previous := pgVersion - 1

		deploymentName := fmt.Sprintf("postgres-release-%d-to-%d-%x", previous, pgVersion, GinkgoT().RandomSeed())
		deleteDeploymentOnCleanup(deploymentName)

		deploy(deploymentName, previous)
		expectRunningMajorVersion(deploymentName, previous)

		By(fmt.Sprintf("writing a marker row on PostgreSQL %d", previous))
		psql(deploymentName, previous, fmt.Sprintf("CREATE TABLE %s (v int); INSERT INTO %[1]s VALUES (%d)", upgradeMarker, previous))

		deploy(deploymentName, pgVersion)
		expectRunningMajorVersion(deploymentName, pgVersion)

		By("checking that the marker row survived the major upgrade")
		Expect(psql(deploymentName, pgVersion,
			fmt.Sprintf("SELECT 'marker=' || v FROM %s", upgradeMarker),
		)).To(ContainSubstring(fmt.Sprintf("marker=%d", previous)))
	})
})
