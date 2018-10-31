package bbr_test

import (
	"time"

	bratsutils "github.com/cloudfoundry/bosh-release-acceptance-tests/brats-utils"
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	"fmt"
	"testing"

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
	bbrReleasePath string
)

var _ = SynchronizedBeforeSuite(func() []byte {
	bbrReleasePath = bratsutils.AssertEnvExists("BBR_RELEASE_PATH")

	bratsutils.Bootstrap()
	bratsutils.CreateAndUploadBOSHRelease()

	session := bratsutils.OuterBosh("-n", "upload-release", bbrReleasePath)
	Eventually(session, 2*time.Minute).Should(gexec.Exit(0))

	bratsutils.StartInnerBosh(
		fmt.Sprintf("-o %s", bratsutils.BoshDeploymentAssetPath("bbr.yml")),
		fmt.Sprintf("-o %s", bratsutils.AssetPath("latest-bbr-release.yml")),
	)

	return nil
}, func(data []byte) {
	bratsutils.Bootstrap()
	bbrBinaryPath = bratsutils.AssertEnvExists("BBR_BINARY_PATH")
	bbrReleasePath = bratsutils.AssertEnvExists("BBR_RELEASE_PATH")
	candidateWardenLinuxStemcellPath = bratsutils.AssertEnvExists("CANDIDATE_STEMCELL_TARBALL_PATH")
})

func bbr(args ...string) *gexec.Session {
	return bratsutils.ExecCommand(bbrBinaryPath, args...)
}
