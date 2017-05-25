package brats_test

import (
	"os"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	"fmt"
	"testing"

	"github.com/onsi/gomega/gexec"
	"os/exec"
	"time"
	"path/filepath"
)

const BLOBSTORE_ACCESS_LOG = "/var/vcap/sys/log/blobstore/blobstore_access.log"

func TestBrats(t *testing.T) {
	RegisterFailHandler(Fail)
	RunSpecs(t, "Brats Suite")
}

var outerBoshBinaryPath , boshBinaryPath, innerBoshPath, innerBoshJumpboxPrivateKeyPath, bbrBinaryPath, innerDirectorIP, boshRelease string

var _ = BeforeSuite(func() {
	outerBoshBinaryPath = assertEnvExists("BOSH_BINARY_PATH")

	innerBoshPath = "/tmp/inner-bosh/director/"
	boshBinaryPath = filepath.Join(innerBoshPath, "bosh")
	innerBoshJumpboxPrivateKeyPath = filepath.Join(innerBoshPath, "jumpbox_private_key.pem")
	bbrBinaryPath = assertEnvExists("BBR_BINARY_PATH")
	boshRelease = assertEnvExists("BOSH_RELEASE")
	innerDirectorIP = "10.245.0.34"

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
