package brats_test

import (
	"fmt"
	"strings"
	"time"

	bratsutils "github.com/cloudfoundry/bosh-release-acceptance-tests/brats-utils"
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
	"github.com/onsi/gomega/gexec"

	"testing"
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
	bratsutils.Bootstrap()
	bratsutils.CreateAndUploadBOSHRelease()
	bratsutils.StartInnerBosh()

	return nil
}, func(data []byte) {
	bratsutils.Bootstrap()
	boshRelease = bratsutils.AssertEnvExists("BOSH_RELEASE")
	dnsReleasePath = bratsutils.AssertEnvExists("DNS_RELEASE_PATH")
	candidateWardenLinuxStemcellPath = bratsutils.AssertEnvExists("CANDIDATE_STEMCELL_TARBALL_PATH")
})

var _ = AfterSuite(func() {
	bratsutils.StopInnerBosh()
})

var _ = AfterEach(func() {
	if !bratsutils.InnerBoshExists() {
		return
	}

	By("cleaning up deployments")
	session := bratsutils.Bosh("deployments", "--column=name")
	Eventually(session, 1*time.Minute).Should(gexec.Exit())
	deployments := strings.Fields(string(session.Out.Contents()))

	for _, deploymentName := range deployments {
		By(fmt.Sprintf("deleting deployment %v", deploymentName))
		if deploymentName == "" {
			continue
		}
		session := bratsutils.Bosh("delete-deployment", "-n", "-d", deploymentName)
		Eventually(session, 5*time.Minute).Should(gexec.Exit())
	}
})
