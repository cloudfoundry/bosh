package brats_test

import (
	"os"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	boshlog "github.com/cloudfoundry/bosh-utils/logger"

	"fmt"
	"testing"

	"github.com/cloudfoundry/bosh-utils/system"
)

const BLOBSTORE_ACCESS_LOG = "/var/vcap/sys/log/blobstore/blobstore_access.log"

func TestBrats(t *testing.T) {
	RegisterFailHandler(Fail)
	RunSpecs(t, "Brats Suite")
}

var cmdRunner system.CmdRunner
var boshBinaryPath, directorIp, sshPrivateKeyPath, boshRelease string

var _ = BeforeSuite(func() {
	cmdRunner = system.NewExecCmdRunner(boshlog.NewLogger(boshlog.LevelNone))
	boshBinaryPath = assertEnvExists("BOSH_BINARY_PATH")
	directorIp = assertEnvExists("BOSH_DIRECTOR_IP")
	sshPrivateKeyPath = assertEnvExists("BOSH_SSH_PRIVATE_KEY_PATH")
	boshRelease = assertEnvExists("BOSH_RELEASE")

	assertEnvExists("BOSH_CLIENT")
	assertEnvExists("BOSH_CLIENT_SECRET")
	assertEnvExists("BOSH_CA_CERT")
	assertEnvExists("BOSH_ENVIRONMENT")
})

func assertEnvExists(envName string) string {
	val, found := os.LookupEnv(envName)
	if !found {
		Fail(fmt.Sprintf("Expected %s", envName))
	}
	return val
}
