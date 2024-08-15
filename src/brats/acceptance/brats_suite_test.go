package acceptance_test

import (
	"fmt"
	"strings"
	"testing"
	"time"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
	"github.com/onsi/gomega/gexec"

	"brats/utils"
)

const BLOBSTORE_ACCESS_LOG = "/var/vcap/sys/log/blobstore/blobstore_access.log"

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

	return nil
}, func(data []byte) {
	utils.Bootstrap()
	boshRelease = utils.AssertEnvExists("BOSH_RELEASE")
	dnsReleasePath = utils.AssertEnvExists("DNS_RELEASE_PATH")
	candidateWardenLinuxStemcellPath = utils.AssertEnvExists("CANDIDATE_STEMCELL_TARBALL_PATH")
})

var _ = AfterSuite(func() {
	utils.StopInnerBosh()
})

var _ = AfterEach(func() {
	if !utils.InnerBoshExists() {
		return
	}

	By("cleaning up deployments")
	session := utils.Bosh("deployments", "--column=name")
	Eventually(session, 1*time.Minute).Should(gexec.Exit())
	deployments := strings.Fields(string(session.Out.Contents()))

	for _, deploymentName := range deployments {
		By(fmt.Sprintf("deleting deployment %v", deploymentName))
		if deploymentName == "" {
			continue
		}
		session := utils.Bosh("delete-deployment", "-n", "-d", deploymentName)
		Eventually(session, 5*time.Minute).Should(gexec.Exit())
	}
})
