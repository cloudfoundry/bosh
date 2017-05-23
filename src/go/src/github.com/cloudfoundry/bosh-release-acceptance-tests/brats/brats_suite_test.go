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
)

const BLOBSTORE_ACCESS_LOG = "/var/vcap/sys/log/blobstore/blobstore_access.log"

func TestBrats(t *testing.T) {
	RegisterFailHandler(Fail)
	RunSpecs(t, "Brats Suite")
}

var boshBinaryPath, bbrBinaryPath, directorIp, sshPrivateKeyPath, boshRelease string

var _ = BeforeSuite(func() {
	boshBinaryPath = assertEnvExists("BOSH_BINARY_PATH")
	bbrBinaryPath = assertEnvExists("BBR_BINARY_PATH")
	directorIp = assertEnvExists("BOSH_DIRECTOR_IP")
	sshPrivateKeyPath = assertEnvExists("BOSH_SSH_PRIVATE_KEY_PATH")
	boshRelease = assertEnvExists("BOSH_RELEASE")

	assertEnvExists("BOSH_CLIENT")
	assertEnvExists("BOSH_CLIENT_SECRET")
	assertEnvExists("BOSH_CA_CERT")
	assertEnvExists("BOSH_ENVIRONMENT")
})

var _ = AfterSuite(func() {
	session, err := gexec.Start(exec.Command(boshBinaryPath, "-n", "clean-up", "--all"), GinkgoWriter, GinkgoWriter)
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
