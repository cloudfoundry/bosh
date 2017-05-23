package brats_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	"fmt"
	"io/ioutil"
	"os"
	"path/filepath"
	"time"
	"strings"
	"sort"
	"github.com/onsi/gomega/gexec"
	"os/exec"
)

var _ = Describe("Brats", func() {
	Context("blobstore nginx", func() {
		Context("When nginx writes to access log", func() {
			var tempBlobstoreDir string

			BeforeEach(func() {
				var err error
				tempBlobstoreDir, err = ioutil.TempDir(os.TempDir(), "blobstore_access")
				Expect(err).ToNot(HaveOccurred())

				session, err := gexec.Start(exec.Command(boshBinaryPath, "upload-release", "-n", boshRelease), GinkgoWriter, GinkgoWriter)
				Expect(err).ToNot(HaveOccurred())
				Expect(session, time.Minute).Should(gexec.Exit(0))

				session, err = gexec.Start(exec.Command("scp", "-o", "UserKnownHostsFile=/dev/null", "-o", "StrictHostKeyChecking=no", "-B", "-i", sshPrivateKeyPath, fmt.Sprintf("jumpbox@%s:%s", directorIp, BLOBSTORE_ACCESS_LOG), tempBlobstoreDir), GinkgoWriter, GinkgoWriter)
				Expect(err).ToNot(HaveOccurred())
				Expect(session, time.Minute).Should(gexec.Exit(0))

			})

			It("Should log in correct format", func() {
				accessContent, err := ioutil.ReadFile(filepath.Join(tempBlobstoreDir, "blobstore_access.log"))
				Expect(err).ToNot(HaveOccurred())
				Expect(string(accessContent)).To(ContainSubstring("CEF:0|CloudFoundry|BOSH|-|blobstore_api|"))
			})
		})
	})

	Context("bosh backup and restore", func() {
		Context("blobstore", func() {
			BeforeEach(func() {
				session, err := gexec.Start(exec.Command("ssh",
					"-o", "UserKnownHostsFile=/dev/null",
					"-o", "StrictHostKeyChecking=no",
					"-i", sshPrivateKeyPath,
					fmt.Sprintf("jumpbox@%s", directorIp),
					"sudo", "rm", "-rf", "/var/vcap/store/blobstore/store.0.bak"), GinkgoWriter, GinkgoWriter)
				Expect(err).ToNot(HaveOccurred())
				Eventually(session, time.Minute).Should(gexec.Exit(0))
			})

			AfterEach(func() {
				session, err := gexec.Start(exec.Command(boshBinaryPath, "-n", "-d", "syslog-deployment", "delete-deployment", "--force"), GinkgoWriter, GinkgoWriter)
				Expect(err).ToNot(HaveOccurred())
				Eventually(session, time.Minute).Should(gexec.Exit(0))

				// Remove the backup created by bbr
				err = os.RemoveAll("bar")
				Expect(err).ToNot(HaveOccurred())

				//_, _, _, err = cmdRunner.RunCommand("ssh",
				//	"-o", "UserKnownHostsFile=/dev/null",
				//	"-o", "StrictHostKeyChecking=no",
				//	"-i", sshPrivateKeyPath,
				//	fmt.Sprintf("jumpbox@%s", directorIp),
				//	"sudo", "rm", "-rf", "/var/vcap/store/blobstore/store.0.bak")
				//Expect(err).ToNot(HaveOccurred())
			})

			It("can backup and restore (removes underlying deployment and release)", func() {
				// Set up a deployment that uses the syslog release
				stemcellUrl := "https://bosh.io/d/stemcells/bosh-warden-boshlite-ubuntu-trusty-go_agent"
				session, err := gexec.Start(exec.Command(boshBinaryPath, "-n", "upload-stemcell", stemcellUrl), GinkgoWriter, GinkgoWriter)
				Expect(err).ToNot(HaveOccurred())
				Eventually(session, time.Minute).Should(gexec.Exit(0))

				syslogRelease := "https://bosh.io/d/github.com/cloudfoundry/syslog-release?v=11"
				session, err = gexec.Start(exec.Command(boshBinaryPath, "-n", "upload-release", syslogRelease), GinkgoWriter, GinkgoWriter)
				Expect(err).ToNot(HaveOccurred())
				Eventually(session, time.Minute).Should(gexec.Exit(0))

				manifestPath, err := filepath.Abs("../assets/syslog-manifest.yml")
				session, err = gexec.Start(exec.Command(boshBinaryPath, "-n",
					"deploy", manifestPath,
					"-d", "syslog-deployment"), GinkgoWriter, GinkgoWriter)
				Expect(err).ToNot(HaveOccurred())
				Eventually(session, 3*time.Minute).Should(gexec.Exit(0))


				// bbr creates a backup
				session, err = gexec.Start(exec.Command(bbrBinaryPath, "director",
					"--name", "bar",
					"--host", fmt.Sprintf("%s:22", directorIp),
					"--username", "jumpbox",
					"--private-key-path", sshPrivateKeyPath,
					"backup"), GinkgoWriter, GinkgoWriter)
				Expect(err).ToNot(HaveOccurred())
				Eventually(session, time.Minute).Should(gexec.Exit(0))

				// @todo remove me; for faster testing, locally backup the blobs so we can restore them later
				session, err = gexec.Start(exec.Command("ssh",
					"-o", "UserKnownHostsFile=/dev/null",
					"-o", "StrictHostKeyChecking=no",
					"-i", sshPrivateKeyPath,
					fmt.Sprintf("jumpbox@%s", directorIp),
					"sudo", "cp", "-rp", "/var/vcap/store/blobstore/store", "/var/vcap/store/blobstore/store.0.bak"), GinkgoWriter, GinkgoWriter)
				Expect(err).ToNot(HaveOccurred())
				Eventually(session, time.Minute).Should(gexec.Exit(0))

				// "wipe" system
				session, err = gexec.Start(exec.Command("ssh",
					"-o", "UserKnownHostsFile=/dev/null",
					"-o", "StrictHostKeyChecking=no",
					"-i", sshPrivateKeyPath,
					fmt.Sprintf("jumpbox@%s", directorIp),
					"sudo", "rm", "-rf", "/var/vcap/store/blobstore/store"), GinkgoWriter, GinkgoWriter)
				Expect(err).ToNot(HaveOccurred())
				Eventually(session, time.Minute).Should(gexec.Exit(0))

				// expect deploy to fail when blobstore is not there
				session, err = gexec.Start(exec.Command(boshBinaryPath, "-n",
					"deploy", manifestPath,
					"-d", "syslog-deployment",
					"--recreate",
				), GinkgoWriter, GinkgoWriter)
				Expect(err).ToNot(HaveOccurred())
				Eventually(session, time.Minute).Should(gexec.Exit(1))

				session, err = gexec.Start(exec.Command(boshBinaryPath, "-n",
					"delete-deployment",
					"-d", "syslog-deployment"), GinkgoWriter, GinkgoWriter)
				Expect(err).ToNot(HaveOccurred())
				Eventually(session, time.Minute).Should(gexec.Exit(0))

				// Delete the release
				session, err = gexec.Start(exec.Command(boshBinaryPath, "-n", "delete-release", "syslog"), GinkgoWriter, GinkgoWriter)
				Expect(err).ToNot(HaveOccurred())
				Eventually(session, time.Minute).Should(gexec.Exit(0))

				session, err = gexec.Start(exec.Command(bbrBinaryPath, "director",
					"--name", "bar",
					"--host", fmt.Sprintf("%s:22", directorIp),
					"--username", "jumpbox",
					"--private-key-path", sshPrivateKeyPath,
					"restore"), GinkgoWriter, GinkgoWriter)
				Expect(err).ToNot(HaveOccurred())
				Eventually(session, time.Minute).Should(gexec.Exit(0))

				waitForBoshDirectorUp()

				session, err = gexec.Start(exec.Command(boshBinaryPath, "-n",
					"-d", "syslog-deployment",
					"cck", "--auto",
				), GinkgoWriter, GinkgoWriter)
				Expect(err).ToNot(HaveOccurred())
				Eventually(session, 3*time.Minute).Should(gexec.Exit(0))

				//validate deployment. instance actually ran the jobs
				session, err = gexec.Start(exec.Command(boshBinaryPath, "-n",
					"-d", "syslog-deployment",
					"vms",
					"--ps",
					"--column=state",
					"--column=instance",
				), GinkgoWriter, GinkgoWriter)
				Expect(err).ToNot(HaveOccurred())
				Eventually(session, time.Minute).Should(gexec.Exit(0))

				Expect(session.Out.Contents()).To(MatchRegexp("syslog_storer/[a-z0-9-]+[ \t]+running"))
				Expect(session.Out.Contents()).To(MatchRegexp("syslog_forwarder/[a-z0-9-]+[ \t]+running"))
			})

			It("can backup and restore (reattaches to underlying deployment)", func() {
				// Set up a deployment that uses the syslog release
				stemcellUrl := "https://bosh.io/d/stemcells/bosh-warden-boshlite-ubuntu-trusty-go_agent"
				session, err := gexec.Start(exec.Command(boshBinaryPath, "-n", "upload-stemcell", stemcellUrl), GinkgoWriter, GinkgoWriter)
				Expect(err).ToNot(HaveOccurred())
				Eventually(session, time.Minute).Should(gexec.Exit(0))

				syslogRelease := "https://bosh.io/d/github.com/cloudfoundry/syslog-release?v=11"
				session, err = gexec.Start(exec.Command(boshBinaryPath, "-n", "upload-release", syslogRelease), GinkgoWriter, GinkgoWriter)
				Expect(err).ToNot(HaveOccurred())
				Eventually(session, time.Minute).Should(gexec.Exit(0))

				manifestPath, err := filepath.Abs("../assets/syslog-manifest.yml")
				session, err = gexec.Start(exec.Command(boshBinaryPath, "-n",
					"deploy", manifestPath,
					"-d", "syslog-deployment"), GinkgoWriter, GinkgoWriter)
				Expect(err).ToNot(HaveOccurred())
				Eventually(session, 3*time.Minute).Should(gexec.Exit(0))


				// bbr creates a backup
				session, err = gexec.Start(exec.Command(bbrBinaryPath, "director",
					"--name", "bar",
					"--host", fmt.Sprintf("%s:22", directorIp),
					"--username", "jumpbox",
					"--private-key-path", sshPrivateKeyPath,
					"backup"), GinkgoWriter, GinkgoWriter)
				Expect(err).ToNot(HaveOccurred())
				Eventually(session, time.Minute).Should(gexec.Exit(0))

				// @todo remove me; for faster testing, locally backup the blobs so we can restore them later
				session, err = gexec.Start(exec.Command("ssh",
					"-o", "UserKnownHostsFile=/dev/null",
					"-o", "StrictHostKeyChecking=no",
					"-i", sshPrivateKeyPath,
					fmt.Sprintf("jumpbox@%s", directorIp),
					"sudo", "cp", "-rp", "/var/vcap/store/blobstore/store", "/var/vcap/store/blobstore/store.0.bak"), GinkgoWriter, GinkgoWriter)
				Expect(err).ToNot(HaveOccurred())
				Eventually(session, time.Minute).Should(gexec.Exit(0))

				// "wipe" system
				session, err = gexec.Start(exec.Command("ssh",
					"-o", "UserKnownHostsFile=/dev/null",
					"-o", "StrictHostKeyChecking=no",
					"-i", sshPrivateKeyPath,
					fmt.Sprintf("jumpbox@%s", directorIp),
					"sudo", "rm", "-rf", "/var/vcap/store/blobstore/*"), GinkgoWriter, GinkgoWriter)
				Expect(err).ToNot(HaveOccurred())
				Eventually(session, time.Minute).Should(gexec.Exit(0))

				session, err = gexec.Start(exec.Command(bbrBinaryPath, "director",
					"--name", "bar",
					"--host", fmt.Sprintf("%s:22", directorIp),
					"--username", "jumpbox",
					"--private-key-path", sshPrivateKeyPath,
					"restore"), GinkgoWriter, GinkgoWriter)
				Expect(err).ToNot(HaveOccurred())
				Eventually(session, time.Minute).Should(gexec.Exit(0))

				waitForBoshDirectorUp()

				session, err = gexec.Start(exec.Command(boshBinaryPath, "-n",
					"-d", "syslog-deployment",
					"cck", "--report",
				), GinkgoWriter, GinkgoWriter)
				Expect(err).ToNot(HaveOccurred())
				Eventually(session, 3*time.Minute).Should(gexec.Exit(0))

				//validate deployment. instance actually ran the jobs
				session, err = gexec.Start(exec.Command(boshBinaryPath, "-n",
					"-d", "syslog-deployment",
					"vms",
					"--ps",
					"--column=state",
					"--column=instance",
				), GinkgoWriter, GinkgoWriter)
				Expect(err).ToNot(HaveOccurred())
				Eventually(session, time.Minute).Should(gexec.Exit(0))

				Expect(session.Out.Contents()).To(MatchRegexp("syslog_storer/[a-z0-9-]+[ \t]+running"))
				Expect(session.Out.Contents()).To(MatchRegexp("syslog_forwarder/[a-z0-9-]+[ \t]+running"))
			})
		})

		Context("blobstore permissions", func(){
			BeforeEach(func() {
				session, err := gexec.Start(exec.Command("ssh",
					"-o", "UserKnownHostsFile=/dev/null",
					"-o", "StrictHostKeyChecking=no",
					"-i", sshPrivateKeyPath,
					fmt.Sprintf("jumpbox@%s", directorIp),
					"sudo", "rm", "-rf", "/var/vcap/store/blobstore/store.1.bak"), GinkgoWriter, GinkgoWriter)
				Expect(err).ToNot(HaveOccurred())
				Eventually(session, time.Minute).Should(gexec.Exit(0))
			})

			AfterEach(func() {
				err := os.RemoveAll("bar")
				Expect(err).ToNot(HaveOccurred())

				//_, _, _, err = cmdRunner.RunCommand("ssh",
				//	"-o", "UserKnownHostsFile=/dev/null",
				//	"-o", "StrictHostKeyChecking=no",
				//	"-i", sshPrivateKeyPath,
				//	fmt.Sprintf("jumpbox@%s", directorIp),
				//	"sudo", "rm", "-rf", "/var/vcap/store/blobstore/store.1.bak")
				//Expect(err).ToNot(HaveOccurred())
			})

			It("restores the blobstore files with the correct permissions/ownership", func() {
				syslogRelease := "https://bosh.io/d/github.com/cloudfoundry/syslog-release?v=11"
				session, err := gexec.Start(exec.Command(boshBinaryPath, "-n", "upload-release", syslogRelease), GinkgoWriter, GinkgoWriter)
				Expect(err).ToNot(HaveOccurred())
				Eventually(session, time.Minute).Should(gexec.Exit(0))

				// store directory/file structure before we do backup
				directoriesBefore, filesBefore := findBlobstoreFiles()

				// do backup
				session, err = gexec.Start(exec.Command(bbrBinaryPath, "director",
					"--name", "bar",
					"--host", fmt.Sprintf("%s:22", directorIp),
					"--username", "jumpbox",
					"--private-key-path", sshPrivateKeyPath,
					"backup"), GinkgoWriter, GinkgoWriter)
				Expect(err).ToNot(HaveOccurred())
				Eventually(session, time.Minute).Should(gexec.Exit(0))

				// Check directories are still there after backup
				directoriesAfter, filesAfter := findBlobstoreFiles()
				Expect(directoriesAfter).To(Equal(directoriesBefore))
				Expect(filesAfter).To(Equal(filesBefore))

				// "wipe" system
				session, err = gexec.Start(exec.Command("ssh",
					"-o", "UserKnownHostsFile=/dev/null",
					"-o", "StrictHostKeyChecking=no",
					"-i", sshPrivateKeyPath,
					fmt.Sprintf("jumpbox@%s", directorIp),
					"sudo", "mv", "/var/vcap/store/blobstore/store", "/var/vcap/store/blobstore/store.1.bak"), GinkgoWriter, GinkgoWriter)
				Expect(err).ToNot(HaveOccurred())
				Eventually(session, time.Minute).Should(gexec.Exit(0))

				session, err = gexec.Start(exec.Command(bbrBinaryPath, "director",
					"--name", "bar",
					"--host", fmt.Sprintf("%s:22", directorIp),
					"--username", "jumpbox",
					"--private-key-path", sshPrivateKeyPath,
					"restore"), GinkgoWriter, GinkgoWriter)
				Expect(err).ToNot(HaveOccurred())
				Eventually(session, time.Minute).Should(gexec.Exit(0))

				// Check directories have correct permissions after restore
				directoriesAfter, filesAfter = findBlobstoreFiles()
				Expect(directoriesAfter).To(Equal(directoriesBefore))
				Expect(filesAfter).To(Equal(filesBefore))
			})
		})
	})
})

func waitForBoshDirectorUp() {
	Eventually(func() *gexec.Session {
		session, err := gexec.Start(exec.Command(
			"curl", "-k", "-f", "-m", "1", "-s",
			fmt.Sprintf("https://%s:25555/info", directorIp)), GinkgoWriter, GinkgoWriter)
		Expect(err).ToNot(HaveOccurred())

		return session
	}, time.Minute, time.Second * 2).Should(gexec.Exit(0))
}

func findBlobstoreFiles() ([]string, []string) {
	session, err := gexec.Start(exec.Command("ssh",
		"-o", "UserKnownHostsFile=/dev/null",
		"-o", "StrictHostKeyChecking=no",
		"-i", sshPrivateKeyPath,
		fmt.Sprintf("jumpbox@%s", directorIp),
		"sudo", "find", "/var/vcap/store/blobstore/store", "-type", "d", "-perm", "0700", "-user", "vcap", "-group", "vcap"), GinkgoWriter, GinkgoWriter)
	Expect(err).ToNot(HaveOccurred())
	Eventually(session, time.Minute).Should(gexec.Exit(0))

	directories := strings.Split(string(session.Out.Contents()), "\n")
	sort.Strings(directories)

	session, err = gexec.Start(exec.Command("ssh",
		"-o", "UserKnownHostsFile=/dev/null",
		"-o", "StrictHostKeyChecking=no",
		"-i", sshPrivateKeyPath,
		fmt.Sprintf("jumpbox@%s", directorIp),
		"sudo", "find", "/var/vcap/store/blobstore/store", "-type", "f", "-perm", "0600", "-user", "vcap", "-group", "vcap"), GinkgoWriter, GinkgoWriter)
	Expect(err).ToNot(HaveOccurred())
	Eventually(session, time.Minute).Should(gexec.Exit(0))

	files := strings.Split(string(session.Out.Contents()), "\n")
	sort.Strings(files)

	return directories, files
}
