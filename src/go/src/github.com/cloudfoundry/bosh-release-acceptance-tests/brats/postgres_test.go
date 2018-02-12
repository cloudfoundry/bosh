package brats_test

import (
	"fmt"
	"path/filepath"
	"time"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
	"github.com/onsi/gomega/gexec"
)

func uploadLocalBoshRelease() {
	tgz, err := filepath.Glob(fmt.Sprintf("%s/*.tgz", boshDirectorReleasePath))
	Expect(err).NotTo(HaveOccurred())
	session := outerBosh("upload-release", tgz[0])
	Eventually(session, 5*time.Minute).Should(gexec.Exit(0))
}

var _ = Describe("postgres-9.4", func() {
	var (
		legacyManifestPath             string
		migrationIncapableManifestPath string
		migrationCapableManifestPath   string
	)

	BeforeEach(func() {
		session := outerBosh("upload-stemcell", candidateWardenLinuxStemcellPath)
		Eventually(session, 5*time.Minute).Should(gexec.Exit(0))

		legacyManifestPath = assetPath("legacy-postgres-manifest.yml")
		migrationIncapableManifestPath = assetPath("postgres-94-manifest.yml")
		migrationCapableManifestPath = assetPath("migratable-postgres-94-manifest.yml")

		session = outerBosh("-d", "postgres", "deploy", "-n", legacyManifestPath)
		Eventually(session, 15*time.Minute).Should(gexec.Exit(0))
	})

	AfterEach(func() {
		session := outerBosh("-d", "postgres", "-n", "delete-deployment")
		Eventually(session, 5*time.Minute).Should(gexec.Exit(0))

		session = outerBosh("clean-up", "--all", "-n")
		Eventually(session, 5*time.Minute).Should(gexec.Exit(0))
	})

	Context("when upgrading a postgres-9.0 job that was never migrated", func() {
		It("should fail to start with a helpful error message", func() {
			uploadLocalBoshRelease()

			session := outerBosh("-d", "postgres", "deploy", "-n", migrationIncapableManifestPath)
			Eventually(session, 15*time.Minute).Should(gexec.Exit(1))

			Expect(string(session.Out.Contents())).To(ContainSubstring("pre-start scripts failed. Failed Jobs: postgres-9.4."))
		})
	})

	Context("When upgrading from a postgres-9.0 job that was migrated", func() {
		It("should deploy without issues", func() {
			session := outerBosh("-d", "postgres", "deploy", "-n", migrationCapableManifestPath)
			Eventually(session, 15*time.Minute).Should(gexec.Exit(0))

			uploadLocalBoshRelease()

			session = outerBosh("-d", "postgres", "deploy", "-n", migrationIncapableManifestPath)
			Eventually(session, 15*time.Minute).Should(gexec.Exit(0))
		})
	})
})
