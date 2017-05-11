package brats_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	"fmt"
	"io/ioutil"
	"os"
	"path/filepath"
	"errors"
	"time"
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

	Context("bosh backup and restore", func() {
		Context("director db", func() {
			It("can backup and restore", func() {
				osConfRelease := "https://bosh.io/d/github.com/cloudfoundry/os-conf-release?v=12"
				_, _, _, err := cmdRunner.RunCommand(boshBinaryPath, "-n", "upload-release", osConfRelease)
				Expect(err).ToNot(HaveOccurred())

				_, _, _, err = cmdRunner.RunCommand("ssh", "-o", "UserKnownHostsFile=/dev/null", "-o", "StrictHostKeyChecking=no", "-i", sshPrivateKeyPath, fmt.Sprintf("jumpbox@%s", directorIp), "sudo mkdir -p /var/vcap/store/director-backup && sudo ARTIFACT_DIRECTORY=/var/vcap/store/director-backup /var/vcap/jobs/director/bin/b-backup")
				Expect(err).ToNot(HaveOccurred())

				_, _, _, err = cmdRunner.RunCommand(boshBinaryPath, "-n", "delete-release", "os-conf/12")
				Expect(err).ToNot(HaveOccurred())

				_, _, _, err = cmdRunner.RunCommand("ssh", "-o", "UserKnownHostsFile=/dev/null", "-o", "StrictHostKeyChecking=no", "-i", sshPrivateKeyPath, fmt.Sprintf("jumpbox@%s", directorIp), "sudo ARTIFACT_DIRECTORY=/var/vcap/store/director-backup /var/vcap/jobs/director/bin/b-restore")
				Expect(err).ToNot(HaveOccurred())

				err = waitForBoshDirectorUp()
				Expect(err).ToNot(HaveOccurred())

				stdout, _, _, err := cmdRunner.RunCommand(boshBinaryPath, "-n", "releases")
				Expect(err).ToNot(HaveOccurred())
				Expect(stdout).To(ContainSubstring("os-conf"))
			})
		})
	})
})

func waitForBoshDirectorUp() error {
	var err error
	retries := 15

	for i := 0; i < retries; i++ {
		// time out after a second: -m 1
		_, _, exit_code, err := cmdRunner.RunCommand(
			"curl", "-k", "-f", "-m", "1", "-s",
			fmt.Sprintf("https://%s:25555/info", directorIp))

		if err == nil && exit_code == 0 {
			return nil
		}

		time.Sleep(2 * time.Second)
	}

	if err != nil {
		return err
	}

	return errors.New("Bosh director failed to come up")
}
