package brats_test

import (
	"fmt"
	"time"

	bratsutils "github.com/cloudfoundry/bosh-release-acceptance-tests/brats-utils"
	"github.com/cloudfoundry/bosh-utils/uuid"
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
	"github.com/onsi/gomega/gexec"
)

var _ = Describe("postgres", func() {
	Context("postgres-9.4", func() {
		var (
			legacyManifestPath             string
			migrationIncapableManifestPath string
			migrationCapableManifestPath   string
			postgresDeploymentName         string
		)

		BeforeEach(func() {
			var err error

			postgresDeploymentName, err = uuid.NewGenerator().Generate()
			Expect(err).NotTo(HaveOccurred())

			legacyManifestPath = bratsutils.AssetPath("legacy-postgres-manifest.yml")
			migrationIncapableManifestPath = bratsutils.AssetPath("unmigratable-postgres-94-manifest.yml")
			migrationCapableManifestPath = bratsutils.AssetPath("migratable-postgres-94-manifest.yml")

			session := bratsutils.OuterBosh("deploy", "-n", legacyManifestPath,
				"-d", postgresDeploymentName,
				"-v", fmt.Sprintf("stemcell-os=%s", bratsutils.StemcellOS()),
				"-v", fmt.Sprintf("deployment-name=%s", postgresDeploymentName),
			)
			Eventually(session, 15*time.Minute).Should(gexec.Exit(0))
		})

		AfterEach(func() {
			session := bratsutils.OuterBosh("-d", postgresDeploymentName, "-n", "delete-deployment")
			Eventually(session, 5*time.Minute).Should(gexec.Exit(0))
		})

		Context("when upgrading a postgres-9.0 job that was never migrated", func() {
			It("should fail to start with a helpful error message", func() {
				session := bratsutils.OuterBosh("deploy", "-n", migrationIncapableManifestPath,
					"-d", postgresDeploymentName,
					"-v", fmt.Sprintf("stemcell-os=%s", bratsutils.StemcellOS()),
					"-v", fmt.Sprintf("deployment-name=%s", postgresDeploymentName),
				)
				Eventually(session, 15*time.Minute).Should(gexec.Exit(1))

				Expect(string(session.Out.Contents())).To(ContainSubstring("pre-start scripts failed. Failed Jobs: postgres-9.4."))
			})
		})

		Context("when upgrading from a postgres-9.0 job that was migrated", func() {
			It("should deploy without issues", func() {
				session := bratsutils.OuterBosh("deploy", "-n", migrationCapableManifestPath,
					"-d", postgresDeploymentName,
					"-v", fmt.Sprintf("stemcell-os=%s", bratsutils.StemcellOS()),
					"-v", fmt.Sprintf("deployment-name=%s", postgresDeploymentName),
				)
				Eventually(session, 15*time.Minute).Should(gexec.Exit(0))

				session = bratsutils.OuterBosh("deploy", "-n", migrationIncapableManifestPath,
					"-d", postgresDeploymentName,
					"-v", fmt.Sprintf("stemcell-os=%s", bratsutils.StemcellOS()),
					"-v", fmt.Sprintf("deployment-name=%s", postgresDeploymentName),
				)
				Eventually(session, 15*time.Minute).Should(gexec.Exit(0))
			})
		})
	})

	Context("postgres-10", func() {
		var (
			postgres94Manifest     string
			postgres10Manifest     string
			postgresDeploymentName string
		)

		BeforeEach(func() {
			var err error

			postgresDeploymentName, err = uuid.NewGenerator().Generate()
			Expect(err).NotTo(HaveOccurred())

			postgres94Manifest = bratsutils.AssetPath("postgres-94-manifest.yml")
			postgres10Manifest = bratsutils.AssetPath("postgres-10-manifest.yml")

			session := bratsutils.OuterBosh("deploy", "-n", postgres94Manifest,
				"-d", postgresDeploymentName,
				"-v", fmt.Sprintf("stemcell-os=%s", bratsutils.StemcellOS()),
				"-v", fmt.Sprintf("deployment-name=%s", postgresDeploymentName),
			)
			Eventually(session, 15*time.Minute).Should(gexec.Exit(0))
		})

		It("Upgrades from 9.4", func() {
			session := bratsutils.OuterBosh("deploy", "-n", postgres10Manifest,
				"-d", postgresDeploymentName,
				"-v", fmt.Sprintf("stemcell-os=%s", bratsutils.StemcellOS()),
				"-v", fmt.Sprintf("deployment-name=%s", postgresDeploymentName),
			)
			Eventually(session, 15*time.Minute).Should(gexec.Exit(0))
		})
	})
})
