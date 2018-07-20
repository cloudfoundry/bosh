package brats_test

import (
	"fmt"
	"time"

	. "github.com/onsi/ginkgo"
	"github.com/onsi/ginkgo/config"
	. "github.com/onsi/gomega"
	"github.com/onsi/gomega/gexec"
)

func postgresDeploymentName() string {
	return fmt.Sprintf("postgres-%d", config.GinkgoConfig.ParallelNode)
}

var _ = Describe("postgres-9.4", func() {
	var (
		legacyManifestPath             string
		migrationIncapableManifestPath string
		migrationCapableManifestPath   string
	)

	BeforeEach(func() {
		legacyManifestPath = assetPath("legacy-postgres-manifest.yml")
		migrationIncapableManifestPath = assetPath("postgres-94-manifest.yml")
		migrationCapableManifestPath = assetPath("migratable-postgres-94-manifest.yml")

		session := outerBosh("deploy", "-n", legacyManifestPath,
			"-d", postgresDeploymentName(),
			"-v", fmt.Sprintf("stemcell-os=%s", stemcellOS),
			"-v", fmt.Sprintf("deployment-name=%s", postgresDeploymentName()),
		)
		Eventually(session, 15*time.Minute).Should(gexec.Exit(0))
	})

	AfterEach(func() {
		session := outerBosh("-d", postgresDeploymentName(), "-n", "delete-deployment")
		Eventually(session, 5*time.Minute).Should(gexec.Exit(0))
	})

	Context("when upgrading a postgres-9.0 job that was never migrated", func() {
		It("should fail to start with a helpful error message", func() {
			session := outerBosh("deploy", "-n", migrationIncapableManifestPath,
				"-d", postgresDeploymentName(),
				"-v", fmt.Sprintf("stemcell-os=%s", stemcellOS),
				"-v", fmt.Sprintf("deployment-name=%s", postgresDeploymentName()),
			)
			Eventually(session, 15*time.Minute).Should(gexec.Exit(1))

			Expect(string(session.Out.Contents())).To(ContainSubstring("pre-start scripts failed. Failed Jobs: postgres-9.4."))
		})
	})

	Context("when upgrading from a postgres-9.0 job that was migrated", func() {
		It("should deploy without issues", func() {
			session := outerBosh("deploy", "-n", migrationCapableManifestPath,
				"-d", postgresDeploymentName(),
				"-v", fmt.Sprintf("stemcell-os=%s", stemcellOS),
				"-v", fmt.Sprintf("deployment-name=%s", postgresDeploymentName()),
			)
			Eventually(session, 15*time.Minute).Should(gexec.Exit(0))

			session = outerBosh("deploy", "-n", migrationIncapableManifestPath,
				"-d", postgresDeploymentName(),
				"-v", fmt.Sprintf("stemcell-os=%s", stemcellOS),
				"-v", fmt.Sprintf("deployment-name=%s", postgresDeploymentName()),
			)
			Eventually(session, 15*time.Minute).Should(gexec.Exit(0))
		})
	})
})
