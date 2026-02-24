package acceptance_test

import (
	"brats/utils"
	"testing"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

func TestBrats(t *testing.T) {
	RegisterFailHandler(Fail)
	RunSpecs(t, "Brats Suite")
}

var (
	boshRelease,
	candidateWardenLinuxStemcellPath,
	dnsReleasePath string
)

var _ = SynchronizedBeforeSuite(func() []byte {
	utils.Bootstrap()
	utils.CreateAndUploadBOSHRelease()
	utils.StartInnerBosh()

	return []byte{}
}, func(data []byte) {
	utils.Bootstrap()
	boshRelease = utils.AssertEnvExists("BOSH_RELEASE")
	dnsReleasePath = utils.AssertEnvExists("DNS_RELEASE_PATH")
	candidateWardenLinuxStemcellPath = utils.AssertEnvExists("CANDIDATE_STEMCELL_TARBALL_PATH")
})

var _ = AfterSuite(func() {
	utils.SuiteCleanup()
})

var _ = AfterEach(func() {
	utils.CleanupInnerBoshDeployments()
})
