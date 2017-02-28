package brats_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
	"github.com/cloudfoundry/bosh-utils/system"

	boshlog "github.com/cloudfoundry/bosh-utils/logger"
	"fmt"
	"os"
	"io/ioutil"
	"path/filepath"
)

var _ = Describe("Brats", func() {

	Context("nginx", func() {
		It("Should log in cef format", func() {
			cmdRunner := system.NewExecCmdRunner(boshlog.NewLogger(boshlog.LevelNone))
			boshBinaryPath := os.Getenv("BOSH_BINARY_PATH")
			directorIp := os.Getenv("BOSH_DIRECTOR_IP")
			sshPrivateKeyPath := os.Getenv("BOSH_SSH_PRIVATE_KEY_PATH")
			blobstoreAccessLog := "/var/vcap/sys/log/blobstore/blobstore_access.log"

			assertEnvExists("BOSH_CLIENT")
			assertEnvExists("BOSH_CLIENT_SECRET")
			assertEnvExists("BOSH_CA_CERT")
			assertEnvExists("BOSH_ENVIRONMENT")

			tempBlobstoreDir, err := ioutil.TempDir(os.TempDir(), "blobstore_access")
			Expect(err).ToNot(HaveOccurred())

			_, _, exitCode, err := cmdRunner.RunCommand(boshBinaryPath, "upload-release", "-n", "https://bosh.io/d/github.com/cloudfoundry/os-conf-release?v=11")
			Expect(err).ToNot(HaveOccurred())
			Expect(exitCode).To(Equal(0))

			_, _, exitCode, err = cmdRunner.RunCommand("scp", "-B", "-i", sshPrivateKeyPath, fmt.Sprintf("jumpbox@%s:%s", directorIp, blobstoreAccessLog), tempBlobstoreDir)
			Expect(err).ToNot(HaveOccurred())
			Expect(exitCode).To(Equal(0))

			accessContent, err := ioutil.ReadFile(filepath.Join(tempBlobstoreDir, "blobstore_access.log"))
			Expect(err).ToNot(HaveOccurred())
			Expect(string(accessContent)).To(ContainSubstring("CEF:0|CloudFoundry|BOSH|-|blobstore_api|"))
		})
	})
})

func assertEnvExists(envName string) {
	if _, found := os.LookupEnv(envName); !found {
		Fail(fmt.Sprintf("Expected %s", envName))
	}
}
