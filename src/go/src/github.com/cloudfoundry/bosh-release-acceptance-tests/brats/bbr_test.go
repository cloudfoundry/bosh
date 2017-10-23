package brats_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"
	"time"

	"github.com/onsi/gomega/gexec"
)

var _ = Describe("Bosh Backup and Restore BBR", func() {
	BeforeEach(startInnerBosh)

	AfterEach(func() {
		err := os.RemoveAll(directorBackupName)
		Expect(err).ToNot(HaveOccurred())

		stopInnerBosh()
	})

	Context("database backup", func() {
		It("can backup and restore (removes underlying deployment and release)", func() {
			syslogManifestPath, err := filepath.Abs("../assets/syslog-manifest.yml")
			Expect(err).ToNot(HaveOccurred())
			osConfManifestPath, err := filepath.Abs("../assets/os-conf-manifest.yml")
			Expect(err).ToNot(HaveOccurred())

			By("create syslog deployment", func() {
				stemcellUrl := "https://bosh.io/d/stemcells/bosh-warden-boshlite-ubuntu-trusty-go_agent"
				session, err := gexec.Start(exec.Command(boshBinaryPath, "-n", "upload-stemcell", stemcellUrl), GinkgoWriter, GinkgoWriter)
				Expect(err).ToNot(HaveOccurred())
				Eventually(session, 5*time.Minute).Should(gexec.Exit(0))

				syslogRelease := "https://bosh.io/d/github.com/cloudfoundry/syslog-release?v=11"
				session, err = gexec.Start(exec.Command(boshBinaryPath, "-n", "upload-release", syslogRelease), GinkgoWriter, GinkgoWriter)
				Expect(err).ToNot(HaveOccurred())
				Eventually(session, 2*time.Minute).Should(gexec.Exit(0))

				session, err = gexec.Start(exec.Command(boshBinaryPath, "-n",
					"deploy", syslogManifestPath,
					"-d", "syslog-deployment"), GinkgoWriter, GinkgoWriter)
				Expect(err).ToNot(HaveOccurred())
				Eventually(session, 3*time.Minute).Should(gexec.Exit(0))
			})

			By("create os-conf deployment", func() {
				osConfRelease := "https://bosh.io/d/github.com/cloudfoundry/os-conf-release?v=12"
				session, err := gexec.Start(exec.Command(boshBinaryPath, "-n", "upload-release", osConfRelease), GinkgoWriter, GinkgoWriter)
				Expect(err).ToNot(HaveOccurred())
				Eventually(session, 2*time.Minute).Should(gexec.Exit(0))

				session, err = gexec.Start(exec.Command(boshBinaryPath, "-n",
					"deploy", osConfManifestPath,
					"-d", "os-conf-deployment"), GinkgoWriter, GinkgoWriter)
				Expect(err).ToNot(HaveOccurred())
				Eventually(session, 3*time.Minute).Should(gexec.Exit(0))
			})

			By("bbr creates a backup", func() {
				session, err := gexec.Start(exec.Command(bbrBinaryPath, "director",
					"--host", fmt.Sprintf("%s:22", innerDirectorIP),
					"--username", innerDirectorUser,
					"--name", directorBackupName,
					"--private-key-path", innerBoshJumpboxPrivateKeyPath,
					"backup"), GinkgoWriter, GinkgoWriter)
				Expect(err).ToNot(HaveOccurred())
				Eventually(session, 2*time.Minute).Should(gexec.Exit(0))
			})

			By("wipe system, recreate inner director", func() {
				stopInnerBosh()

				startInnerBosh()
			})

			By("expect deploy to fail because the release/stemcell won't be there", func() {
				session, err := gexec.Start(exec.Command(boshBinaryPath, "-n",
					"deploy", syslogManifestPath,
					"-d", "syslog-deployment",
					"--recreate",
				), GinkgoWriter, GinkgoWriter)
				Expect(err).ToNot(HaveOccurred())
				Eventually(session, time.Minute).Should(gexec.Exit(1))
			})

			By("restore inner director from backup", func() {
				session, err := gexec.Start(exec.Command(bbrBinaryPath, "director",
					"--host", fmt.Sprintf("%s:22", innerDirectorIP),
					"--username", innerDirectorUser,
					"--name", directorBackupName,
					"--private-key-path", innerBoshJumpboxPrivateKeyPath,
					"restore"), GinkgoWriter, GinkgoWriter)
				Expect(err).ToNot(HaveOccurred())
				Eventually(session, 2*time.Minute).Should(gexec.Exit(0))

				waitForBoshDirectorUp(boshBinaryPath)

				stemcellUrl := "https://bosh.io/d/stemcells/bosh-warden-boshlite-ubuntu-trusty-go_agent"
				session, err = gexec.Start(exec.Command(boshBinaryPath, "-n", "upload-stemcell", "--fix", stemcellUrl), GinkgoWriter, GinkgoWriter)
				Expect(err).ToNot(HaveOccurred())
				Eventually(session, 5*time.Minute).Should(gexec.Exit(0))
			})

			By("cck the deployments", func() {
				session, err := gexec.Start(exec.Command(boshBinaryPath, "-n",
					"-d", "syslog-deployment",
					"cck", "--auto",
				), GinkgoWriter, GinkgoWriter)
				Expect(err).ToNot(HaveOccurred())
				Eventually(session, 10*time.Minute).Should(gexec.Exit(0))

				session, err = gexec.Start(exec.Command(boshBinaryPath, "-n",
					"-d", "os-conf-deployment",
					"cck",
					"--resolution", "delete_vm_reference",
					"--resolution", "delete_disk_reference",
				), GinkgoWriter, GinkgoWriter)
				Expect(err).ToNot(HaveOccurred())
				Eventually(session, 10*time.Minute).Should(gexec.Exit(0))

				session, err = gexec.Start(exec.Command(boshBinaryPath, "-n",
					"deploy", osConfManifestPath,
					"-d", "os-conf-deployment"), GinkgoWriter, GinkgoWriter)
				Expect(err).ToNot(HaveOccurred())
				Eventually(session, 3*time.Minute).Should(gexec.Exit(0))
			})

			By("validate deployments", func() {
				By("instance actually ran the jobs", func() {
					session, err := gexec.Start(exec.Command(boshBinaryPath, "-n",
						"-d", "syslog-deployment",
						"instances",
						"--ps",
						"--column=process_state",
						"--column=instance",
					), GinkgoWriter, GinkgoWriter)
					Expect(err).ToNot(HaveOccurred())
					Eventually(session, time.Minute).Should(gexec.Exit(0))

					Expect(session.Out.Contents()).To(MatchRegexp("syslog_storer/[a-z0-9-]+[ \t]+running"))
					Expect(session.Out.Contents()).To(MatchRegexp("syslog_forwarder/[a-z0-9-]+[ \t]+running"))
				})

				By("persistent disks exist", func() {
					session, err := gexec.Start(exec.Command(boshBinaryPath, "-n",
						"-d", "os-conf-deployment",
						"instances", "--details",
						"--column", "disk_cids",
					), GinkgoWriter, GinkgoWriter)

					Expect(err).ToNot(HaveOccurred())
					Eventually(session, time.Minute).Should(gexec.Exit(0))

					Expect(string(session.Out.Contents())).To(MatchRegexp("[0-9a-f]{8}-[0-9a-f-]{27}"))
				})
			})
		})

		It("can backup and restore (reattaches to underlying deployment)", func() {
			By("Set up a deployment that uses the syslog release", func() {
				stemcellUrl := "https://bosh.io/d/stemcells/bosh-warden-boshlite-ubuntu-trusty-go_agent"
				session, err := gexec.Start(exec.Command(boshBinaryPath, "-n", "upload-stemcell", stemcellUrl), GinkgoWriter, GinkgoWriter)
				Expect(err).ToNot(HaveOccurred())
				Eventually(session, 5*time.Minute).Should(gexec.Exit(0))

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
			})

			By("bbr creates a backup", func() {
				session, err := gexec.Start(exec.Command(bbrBinaryPath, "director",
					"--host", fmt.Sprintf("%s:22", innerDirectorIP),
					"--username", innerDirectorUser,
					"--name", directorBackupName,
					"--private-key-path", innerBoshJumpboxPrivateKeyPath,
					"backup"), GinkgoWriter, GinkgoWriter)
				Expect(err).ToNot(HaveOccurred())
				Eventually(session, time.Minute).Should(gexec.Exit(0))
			})

			By("wipe system", func() {
				session, err := gexec.Start(exec.Command(outerBoshBinaryPath, "-d", "bosh",
					"ssh", "bosh", "sudo rm -rf /var/vcap/store/blobstore/*"), GinkgoWriter, GinkgoWriter)
				Expect(err).ToNot(HaveOccurred())
				Eventually(session, 5*time.Minute).Should(gexec.Exit(0))

				session, err = gexec.Start(exec.Command(bbrBinaryPath, "director",
					"--host", fmt.Sprintf("%s:22", innerDirectorIP),
					"--username", innerDirectorUser,
					"--name", directorBackupName,
					"--private-key-path", innerBoshJumpboxPrivateKeyPath,
					"restore"), GinkgoWriter, GinkgoWriter)
				Expect(err).ToNot(HaveOccurred())
				Eventually(session, time.Minute).Should(gexec.Exit(0))

				waitForBoshDirectorUp(boshBinaryPath)

				stemcellUrl := "https://bosh.io/d/stemcells/bosh-warden-boshlite-ubuntu-trusty-go_agent"
				session, err = gexec.Start(exec.Command(boshBinaryPath, "-n", "upload-stemcell", "--fix", stemcellUrl), GinkgoWriter, GinkgoWriter)
				Expect(err).ToNot(HaveOccurred())
				Eventually(session, 5*time.Minute).Should(gexec.Exit(0))

				session, err = gexec.Start(exec.Command(boshBinaryPath, "-n",
					"-d", "syslog-deployment",
					"cck", "--report",
				), GinkgoWriter, GinkgoWriter)
				Expect(err).ToNot(HaveOccurred())
				Eventually(session, 3*time.Minute).Should(gexec.Exit(0))
			})

			By("validate deployment. instance actually ran the jobs", func() {
				session, err := gexec.Start(exec.Command(boshBinaryPath, "-n",
					"-d", "syslog-deployment",
					"instances",
					"--ps",
					"--column=process_state",
					"--column=instance",
				), GinkgoWriter, GinkgoWriter)
				Expect(err).ToNot(HaveOccurred())
				Eventually(session, time.Minute).Should(gexec.Exit(0))

				Expect(session.Out.Contents()).To(MatchRegexp("syslog_storer/[a-z0-9-]+[ \t]+running"))
				Expect(session.Out.Contents()).To(MatchRegexp("syslog_forwarder/[a-z0-9-]+[ \t]+running"))
			})
		})
	})

	Context("blobstore files", func() {
		var directoriesBefore, filesBefore []string

		It("backs up an empty blobstore", func() {
			By("Backup deployment", func() {
				session, err := gexec.Start(exec.Command(bbrBinaryPath, "director",
					"--host", fmt.Sprintf("%s:22", innerDirectorIP),
					"--username", innerDirectorUser,
					"--name", directorBackupName,
					"--private-key-path", innerBoshJumpboxPrivateKeyPath,
					"backup"), GinkgoWriter, GinkgoWriter)
				Expect(err).ToNot(HaveOccurred())
				Eventually(session, time.Minute).Should(gexec.Exit(0))
			})

			By("Restore deployment", func() {
				session, err := gexec.Start(exec.Command(bbrBinaryPath, "director",
					"--host", fmt.Sprintf("%s:22", innerDirectorIP),
					"--username", innerDirectorUser,
					"--name", directorBackupName,
					"--private-key-path", innerBoshJumpboxPrivateKeyPath,
					"restore"), GinkgoWriter, GinkgoWriter)
				Expect(err).ToNot(HaveOccurred())
				Eventually(session, time.Minute).Should(gexec.Exit(0))

				waitForBoshDirectorUp(boshBinaryPath)
			})
		})

		It("restores the blobstore files with the correct permissions/ownership", func() {
			By("Upload a release", func() {
				syslogRelease := "https://bosh.io/d/github.com/cloudfoundry/syslog-release?v=11"
				session, err := gexec.Start(exec.Command(boshBinaryPath, "-n", "upload-release", syslogRelease), GinkgoWriter, GinkgoWriter)
				Expect(err).ToNot(HaveOccurred())
				Eventually(session, time.Minute).Should(gexec.Exit(0))
			})

			By("Store directory/file structure before we do backup", func() {
				directoriesBefore, filesBefore = findBlobstoreFiles(outerBoshBinaryPath)
			})

			By("Backup deployment", func() {
				session, err := gexec.Start(exec.Command(bbrBinaryPath, "director",
					"--host", fmt.Sprintf("%s:22", innerDirectorIP),
					"--username", innerDirectorUser,
					"--name", directorBackupName,
					"--private-key-path", innerBoshJumpboxPrivateKeyPath,
					"backup"), GinkgoWriter, GinkgoWriter)
				Expect(err).ToNot(HaveOccurred())
				Eventually(session, time.Minute).Should(gexec.Exit(0))
			})

			By("Check directories are still there after backup", func() {
				directoriesAfter, filesAfter := findBlobstoreFiles(outerBoshBinaryPath)
				Expect(directoriesAfter).To(Equal(directoriesBefore))
				Expect(filesAfter).To(Equal(filesBefore))
			})

			By("\"wipe\" system", func() {
				session, err := gexec.Start(exec.Command(outerBoshBinaryPath, "-d", "bosh", "ssh", "bosh", "-c", "sudo rm -rf /var/vcap/store/blobstore/*"), GinkgoWriter, GinkgoWriter)
				Expect(err).ToNot(HaveOccurred())
				Eventually(session, 5*time.Minute).Should(gexec.Exit(0))
			})

			By("Restore deployment", func() {
				session, err := gexec.Start(exec.Command(bbrBinaryPath, "director",
					"--host", fmt.Sprintf("%s:22", innerDirectorIP),
					"--username", innerDirectorUser,
					"--name", directorBackupName,
					"--private-key-path", innerBoshJumpboxPrivateKeyPath,
					"restore"), GinkgoWriter, GinkgoWriter)
				Expect(err).ToNot(HaveOccurred())
				Eventually(session, time.Minute).Should(gexec.Exit(0))

				waitForBoshDirectorUp(boshBinaryPath)
			})

			By("Check directories have correct permissions after restore", func() {
				directoriesAfter, filesAfter := findBlobstoreFiles(outerBoshBinaryPath)
				Expect(directoriesAfter).To(Equal(directoriesBefore))
				Expect(filesAfter).To(Equal(filesBefore))
			})
		})
	})
})

func waitForBoshDirectorUp(boshBinaryPath string) {
	Eventually(func() *gexec.Session {
		session, err := gexec.Start(exec.Command(boshBinaryPath, "env"), GinkgoWriter, GinkgoWriter)
		Expect(err).ToNot(HaveOccurred())
		session.Wait()
		return session
	}, 5*time.Minute, time.Second*2).Should(gexec.Exit(0))
}

func findBlobstoreFiles(outerBoshBinaryPath string) ([]string, []string) {
	session, err := gexec.Start(exec.Command(outerBoshBinaryPath, "-d", "bosh", "ssh", "bosh", "--results", "--column", "stdout",
		"sudo find /var/vcap/store/blobstore/store -type d -perm 0700 -user vcap -group vcap"), GinkgoWriter, GinkgoWriter)
	Expect(err).ToNot(HaveOccurred())
	Eventually(session, time.Minute).Should(gexec.Exit(0))

	directories := strings.Split(string(session.Out.Contents()), "\n")
	sort.Strings(directories)

	session, err = gexec.Start(exec.Command(outerBoshBinaryPath, "-d", "bosh", "ssh", "bosh", "-r", "--column", "stdout",
		"sudo find /var/vcap/store/blobstore/store -type f -perm 0600 -user vcap -group vcap"), GinkgoWriter, GinkgoWriter)
	Expect(err).ToNot(HaveOccurred())
	Eventually(session, time.Minute).Should(gexec.Exit(0))

	files := strings.Split(string(session.Out.Contents()), "\n")
	sort.Strings(files)

	return directories, files
}
