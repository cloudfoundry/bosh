package bbr_test

import (
	"strings"

	bratsutils "github.com/cloudfoundry/bosh-release-acceptance-tests/brats-utils"
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	"fmt"
	"testing"

	"time"

	"github.com/onsi/gomega/gexec"
)

const BLOBSTORE_ACCESS_LOG = "/var/vcap/sys/log/blobstore/blobstore_access.log"

func TestBBR(t *testing.T) {
	RegisterFailHandler(Fail)
	RunSpecs(t, "BBR Suite")
}

var (
	candidateWardenLinuxStemcellPath,
	bbrBinaryPath string
)

var _ = SynchronizedBeforeSuite(func() []byte {
	bratsutils.Bootstrap()
	bratsutils.CreateAndUploadBOSHRelease()
	bratsutils.StartInnerBosh(
		fmt.Sprintf("-o %s", bratsutils.BoshDeploymentAssetPath("bbr.yml")),
		fmt.Sprintf("-o %s", bratsutils.AssetPath("latest-bbr-release.yml")),
	)

	return nil
}, func(data []byte) {
	bratsutils.Bootstrap()
	bbrBinaryPath = bratsutils.AssertEnvExists("BBR_BINARY_PATH")
	candidateWardenLinuxStemcellPath = bratsutils.AssertEnvExists("CANDIDATE_STEMCELL_TARBALL_PATH")
})

var _ = AfterSuite(func() {
	bratsutils.StopInnerBosh()
})

var _ = AfterEach(func() {
	By("cleanin up deployments")
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

func bbr(args ...string) *gexec.Session {
	return bratsutils.ExecCommand(bbrBinaryPath, args...)
}
