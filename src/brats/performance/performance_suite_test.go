package performance_test

import (
	"testing"
	"time"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
	"github.com/onsi/gomega/gexec"

	"brats/utils"
)

const outerBoshTimeout = 10 * time.Minute

func TestPerformance(t *testing.T) {
	RegisterFailHandler(Fail)
	RunSpecs(t, "Performance Suite")
}

var _ = SynchronizedBeforeSuite(func() {
	utils.Bootstrap()
	directorTarballPath := utils.AssertEnvExists("BOSH_DIRECTOR_TARBALL_PATH")
	session := utils.OuterBosh("upload-release", directorTarballPath)
	Eventually(session, outerBoshTimeout).Should(gexec.Exit(0))

	directorReleasePath := utils.AssertEnvExists("BOSH_DIRECTOR_RELEASE_PATH")
	session = utils.OuterBosh("create-release", "--dir", directorReleasePath)
	Eventually(session, outerBoshTimeout).Should(gexec.Exit(0))

	session = utils.OuterBosh("upload-release", "--dir", directorReleasePath, "--rebase")
	Eventually(session, outerBoshTimeout).Should(gexec.Exit(0))
}, func() {
	utils.Bootstrap()
})

var _ = AfterSuite(func() {
	utils.SuiteCleanup()
})

var _ = AfterEach(func() {
	utils.CleanupInnerBoshDeployments()
})
