package bbr_test

import (
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
	bratsutils.Bootstrap()
	bratsutils.CreateAndUploadBOSHRelease()
	bratsutils.StartInnerBosh(
		fmt.Sprintf("-o %s", bratsutils.BoshDeploymentAssetPath("bbr.yml")),
		fmt.Sprintf("-o %s", bratsutils.AssetPath("latest-bbr-release.yml")),
		fmt.Sprintf("-v bbr_release_path=%s", bbrReleasePath),
	)

	return nil
}, func(data []byte) {
	bratsutils.Bootstrap()
	bbrBinaryPath = bratsutils.AssertEnvExists("BBR_BINARY_PATH")
	candidateWardenLinuxStemcellPath = bratsutils.AssertEnvExists("CANDIDATE_STEMCELL_TARBALL_PATH")
	bbrReleasePath = bratsutils.AssertEnvExists("BBR_RELEASE_PATH")
})

func bbr(args ...string) *gexec.Session {
	return bratsutils.ExecCommand(bbrBinaryPath, args...)
}
