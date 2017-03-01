package brats_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	"fmt"
	"io/ioutil"
	"os"
	"path/filepath"
)

var _ = Describe("Brats", func() {

	Context("blobstore nginx", func() {
		Context("When nginx writes to access log", func() {
			var tempBlobstoreDir string

			BeforeEach(func() {
				var err error
				tempBlobstoreDir, err = ioutil.TempDir(os.TempDir(), "blobstore_access")
				Expect(err).ToNot(HaveOccurred())

				_, _, exitCode, err := cmdRunner.RunCommand(boshBinaryPath, "upload-release", "-n", boshRelease)
				Expect(err).ToNot(HaveOccurred())
				Expect(exitCode).To(Equal(0))

				_, _, exitCode, err = cmdRunner.RunCommand("scp","-o", "UserKnownHostsFile=/dev/null", "-o", "StrictHostKeyChecking=no", "-B", "-i", sshPrivateKeyPath, fmt.Sprintf("jumpbox@%s:%s", directorIp, BLOBSTORE_ACCESS_LOG), tempBlobstoreDir)
				Expect(err).ToNot(HaveOccurred())
				Expect(exitCode).To(Equal(0))

			})

			It("Should log in correct format", func() {
				accessContent, err := ioutil.ReadFile(filepath.Join(tempBlobstoreDir, "blobstore_access.log"))
				Expect(err).ToNot(HaveOccurred())
				Expect(string(accessContent)).To(ContainSubstring("CEF:0|CloudFoundry|BOSH|-|blobstore_api|"))
			})
		})
	})
})
