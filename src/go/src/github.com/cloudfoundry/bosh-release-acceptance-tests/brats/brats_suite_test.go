package brats_test

import (
	"os"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	"fmt"
	"testing"

	"os/exec"
	"time"

	"path/filepath"

	"github.com/onsi/gomega/gexec"
)

const BLOBSTORE_ACCESS_LOG = "/var/vcap/sys/log/blobstore/blobstore_access.log"

func TestBrats(t *testing.T) {
	RegisterFailHandler(Fail)
	RunSpecs(t, "Brats Suite")
}

var (
	outerBoshBinaryPath,
	boshBinaryPath,
	innerBoshPath,
	innerBoshJumpboxPrivateKeyPath,
	bbrBinaryPath,
	innerDirectorIP,
	boshRelease,
	directorBackupName,
	innerDirectorUser,
	deploymentName,
	boshDirectorReleasePath,
	candidateWardenLinuxStemcellPath,
	dnsReleasePath string
)

var _ = BeforeSuite(func() {
	outerBoshBinaryPath = assertEnvExists("BOSH_BINARY_PATH")

	deploymentName = "dns-with-templates"
	directorBackupName = "director-backup"
	innerDirectorUser = "jumpbox"
	innerBoshPath = "/tmp/inner-bosh/director/"
	boshBinaryPath = filepath.Join(innerBoshPath, "bosh")
	innerBoshJumpboxPrivateKeyPath = filepath.Join(innerBoshPath, "jumpbox_private_key.pem")
	bbrBinaryPath = assertEnvExists("BBR_BINARY_PATH")
	boshRelease = assertEnvExists("BOSH_RELEASE")
	innerDirectorIP = "10.245.0.34"
	dnsReleasePath = assertEnvExists("DNS_RELEASE_PATH")
	boshDirectorReleasePath = assertEnvExists("BOSH_DIRECTOR_RELEASE_PATH")
	candidateWardenLinuxStemcellPath = assertEnvExists("CANDIDATE_STEMCELL_TARBALL_PATH")

	assertEnvExists("BOSH_ENVIRONMENT")
})

var _ = AfterSuite(func() {
	session, err := gexec.Start(exec.Command(outerBoshBinaryPath, "-n", "clean-up", "--all"), GinkgoWriter, GinkgoWriter)
	Expect(err).ToNot(HaveOccurred())
	Eventually(session, time.Minute).Should(gexec.Exit(0))
})

func assertEnvExists(envName string) string {
	val, found := os.LookupEnv(envName)
	if !found {
		Fail(fmt.Sprintf("Expected %s", envName))
	}
	return val
}

func startInnerBosh() {
	cmd := exec.Command(fmt.Sprintf("../../../../../../../ci/docker/main-bosh-docker/start-inner-bosh.sh"))
	cmd.Env = os.Environ()
	cmd.Env = append(cmd.Env, fmt.Sprintf("bosh_release_path=%s", boshDirectorReleasePath))

	session, err := gexec.Start(cmd, GinkgoWriter, GinkgoWriter)
	Expect(err).ToNot(HaveOccurred())
	Eventually(session, 25*time.Minute).Should(gexec.Exit(0))
}

func stopInnerBosh() {
	session, err := gexec.Start(exec.Command("../../../../../../../ci/docker/main-bosh-docker/destroy-inner-bosh.sh"), GinkgoWriter, GinkgoWriter)
	Expect(err).ToNot(HaveOccurred())
	Eventually(session, 15*time.Minute).Should(gexec.Exit(0))
}
