package performance_test

import (
	"testing"
	"time"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
	"github.com/onsi/gomega/gexec"

	"brats/utils"
)

func TestPerformance(t *testing.T) {
	RegisterFailHandler(Fail)
	RunSpecs(t, "Performance Suite")
}

var _ = SynchronizedBeforeSuite(func() {
	utils.Bootstrap()
	utils.OuterBosh("upload-release", utils.AssertEnvExists("BOSH_DIRECTOR_TARBALL_PATH"))
	directorReleasePath := utils.AssertEnvExists("BOSH_DIRECTOR_RELEASE_PATH")
	session := utils.OuterBosh("create-release", "--dir", directorReleasePath)
	Eventually(session, 1*time.Minute).Should(gexec.Exit())
	session = utils.OuterBosh("upload-release", "--dir", directorReleasePath, "--rebase")
	Eventually(session, 1*time.Minute).Should(gexec.Exit())
}, func() {
	utils.Bootstrap()
})

var _ = AfterSuite(func() {
	utils.SuiteCleanup()
})

var _ = AfterEach(func() {
	utils.CleanupInnerBoshDeployments()
})
