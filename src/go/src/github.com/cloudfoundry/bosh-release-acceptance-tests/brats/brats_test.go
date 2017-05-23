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

	BeforeEach(func() {
		session, err := gexec.Start(exec.Command("../../../../../../../ci/docker/main-bosh-docker/start-inner-bosh.sh"), GinkgoWriter, GinkgoWriter)
		Expect(err).ToNot(HaveOccurred())
		Eventually(session, 15 * time.Minute).Should(gexec.Exit(0))
	})

	AfterEach(func() {
		session, err := gexec.Start(exec.Command("../../../../../../../ci/docker/main-bosh-docker/destroy-inner-bosh.sh"), GinkgoWriter, GinkgoWriter)
		Expect(err).ToNot(HaveOccurred())
		Eventually(session, 5 * time.Minute).Should(gexec.Exit(0))
	})

	Context("blobstore nginx", func() {
		Context("When nginx writes to access log", func() {
			var tempBlobstoreDir string

			BeforeEach(func() {
				var err error
				tempBlobstoreDir, err = ioutil.TempDir(os.TempDir(), "blobstore_access")
				Expect(err).ToNot(HaveOccurred())

				session, err := gexec.Start(exec.Command(boshBinaryPath, "upload-release", "-n", boshRelease), GinkgoWriter, GinkgoWriter)
				Expect(err).ToNot(HaveOccurred())
				Eventually(session, time.Minute).Should(gexec.Exit(0))

				session, err = gexec.Start(exec.Command(outerBoshBinaryPath, "-d", "bosh", "scp", fmt.Sprintf("bosh:%s", BLOBSTORE_ACCESS_LOG), tempBlobstoreDir), GinkgoWriter, GinkgoWriter)
				Expect(err).ToNot(HaveOccurred())
				Eventually(session, time.Minute).Should(gexec.Exit(0))
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
			var boshDeploymentName string

			BeforeEach(func() {
				boshDeploymentName = "bosh"
			})

			AfterEach(func() {
				// Remove the backup created by bbr
				err := os.RemoveAll(boshDeploymentName)
				Expect(err).ToNot(HaveOccurred())
			})

			It("can backup and restore (removes underlying deployment and release)", func() {
				manifestPath, err := filepath.Abs("../assets/syslog-manifest.yml")
				Expect(err).ToNot(HaveOccurred())

				By("create syslog deployment", func() {
					stemcellUrl := "https://bosh.io/d/stemcells/bosh-warden-boshlite-ubuntu-trusty-go_agent"
					session, err := gexec.Start(exec.Command(boshBinaryPath, "-n", "upload-stemcell", stemcellUrl), GinkgoWriter, GinkgoWriter)
					Expect(err).ToNot(HaveOccurred())
					Eventually(session, 5 * time.Minute).Should(gexec.Exit(0))

					syslogRelease := "https://bosh.io/d/github.com/cloudfoundry/syslog-release?v=11"
					session, err = gexec.Start(exec.Command(boshBinaryPath, "-n", "upload-release", syslogRelease), GinkgoWriter, GinkgoWriter)
					Expect(err).ToNot(HaveOccurred())
					Eventually(session, 2 * time.Minute).Should(gexec.Exit(0))

					session, err = gexec.Start(exec.Command(boshBinaryPath, "-n",
						"deploy", manifestPath,
						"-d", "syslog-deployment"), GinkgoWriter, GinkgoWriter)
					Expect(err).ToNot(HaveOccurred())
					Eventually(session, 3 * time.Minute).Should(gexec.Exit(0))
				})

				By("bbr creates a backup", func() {
					session, err := gexec.Start(exec.Command(bbrBinaryPath, "deployment",
						"--target", fmt.Sprintf("https://%s:25555", directorIp),
						"--username", boshClient,
						"--password", boshClientSecret,
						"--ca-cert", boshCACert,
						"--deployment", boshDeploymentName,
						"backup"), GinkgoWriter, GinkgoWriter)
					Expect(err).ToNot(HaveOccurred())
					Eventually(session, time.Minute).Should(gexec.Exit(0))
				})

				By("wipe system, recreate inner director", func() {
					session, err := gexec.Start(exec.Command("../../../../../../../ci/docker/main-bosh-docker/destroy-inner-bosh.sh"), GinkgoWriter, GinkgoWriter)
					Expect(err).ToNot(HaveOccurred())
					Eventually(session, 5 * time.Minute).Should(gexec.Exit(0))

					session, err = gexec.Start(exec.Command("../../../../../../../ci/docker/main-bosh-docker/start-inner-bosh.sh"), GinkgoWriter, GinkgoWriter)
					Expect(err).ToNot(HaveOccurred())
					Eventually(session, 3 * time.Minute).Should(gexec.Exit(0))
				})

				By("expect deploy to fail because the deployment won't be there", func() {
					session, err := gexec.Start(exec.Command(boshBinaryPath, "-n",
						"deploy", manifestPath,
						"-d", "syslog-deployment",
						"--recreate",
					), GinkgoWriter, GinkgoWriter)
					Expect(err).ToNot(HaveOccurred())
					Eventually(session, time.Minute).Should(gexec.Exit(1))
				})

				By("restore inner director from backup", func() {
					session, err := gexec.Start(exec.Command(bbrBinaryPath, "deployment",
						"--target", fmt.Sprintf("https://%s:25555", directorIp),
						"--username", boshClient,
						"--password", boshClientSecret,
						"--ca-cert", boshCACert,
						"--deployment", boshDeploymentName,
						"restore"), GinkgoWriter, GinkgoWriter)
					Expect(err).ToNot(HaveOccurred())
					Eventually(session, time.Minute).Should(gexec.Exit(0))

					waitForBoshDirectorUp(boshBinaryPath)

					session, err = gexec.Start(exec.Command(boshBinaryPath, "-n",
						"-d", "syslog-deployment",
						"cck", "--auto",
					), GinkgoWriter, GinkgoWriter)
					Expect(err).ToNot(HaveOccurred())
					Eventually(session, 3 * time.Minute).Should(gexec.Exit(0))
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

			It("can backup and restore (reattaches to underlying deployment)", func() {
				By("Set up a deployment that uses the syslog release", func() {
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
					Eventually(session, 3 * time.Minute).Should(gexec.Exit(0))
				})


				By("bbr creates a backup", func() {
					session, err := gexec.Start(exec.Command(bbrBinaryPath, "deployment",
						"--target", fmt.Sprintf("https://%s:25555", directorIp),
						"--username", boshClient,
						"--password", boshClientSecret,
						"--ca-cert", boshCACert,
						"--deployment", boshDeploymentName,
						"backup"), GinkgoWriter, GinkgoWriter)
					Expect(err).ToNot(HaveOccurred())
					Eventually(session, time.Minute).Should(gexec.Exit(0))
				})

				By("wipe system", func() {
					session, err := gexec.Start(exec.Command(outerBoshBinaryPath, "-d", "bosh",
						"ssh", "bosh", "sudo rm -rf /var/vcap/store/blobstore/*"), GinkgoWriter, GinkgoWriter)
					Expect(err).ToNot(HaveOccurred())
					Eventually(session, 5 * time.Minute).Should(gexec.Exit(0))

					session, err = gexec.Start(exec.Command(bbrBinaryPath, "deployment",
						"--target", fmt.Sprintf("https://%s:25555", directorIp),
						"--username", boshClient,
						"--password", boshClientSecret,
						"--ca-cert", boshCACert,
						"--deployment", boshDeploymentName,
						"restore"), GinkgoWriter, GinkgoWriter)
					Expect(err).ToNot(HaveOccurred())
					Eventually(session, time.Minute).Should(gexec.Exit(0))

					waitForBoshDirectorUp(boshBinaryPath)

					session, err = gexec.Start(exec.Command(boshBinaryPath, "-n",
						"-d", "syslog-deployment",
						"cck", "--report",
					), GinkgoWriter, GinkgoWriter)
					Expect(err).ToNot(HaveOccurred())
					Eventually(session, 3 * time.Minute).Should(gexec.Exit(0))
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

		Context("blobstore permissions", func() {
			var directoriesBefore, filesBefore []string
			AfterEach(func() {
				err := os.RemoveAll("bosh")
				Expect(err).ToNot(HaveOccurred())
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
					session, err := gexec.Start(exec.Command(bbrBinaryPath, "deployment",
						"--target", fmt.Sprintf("https://%s:25555", directorIp),
						"--username", boshClient,
						"--password", boshClientSecret,
						"--ca-cert", boshCACert,
						"--deployment", "bosh",
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
					Eventually(session, 5 * time.Minute).Should(gexec.Exit(0))
				})

				By("Restore deployment", func() {
					session, err := gexec.Start(exec.Command(bbrBinaryPath, "deployment",
						"--target", fmt.Sprintf("https://%s:25555", directorIp),
						"--username", boshClient,
						"--password", boshClientSecret,
						"--ca-cert", boshCACert,
						"--deployment", "bosh",
						"restore"), GinkgoWriter, GinkgoWriter)
					Expect(err).ToNot(HaveOccurred())
					Eventually(session, time.Minute).Should(gexec.Exit(0))
				})

				By("Check directories have correct permissions after restore", func() {
					directoriesAfter, filesAfter := findBlobstoreFiles(outerBoshBinaryPath)
					Expect(directoriesAfter).To(Equal(directoriesBefore))
					Expect(filesAfter).To(Equal(filesBefore))
				})
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
	}, 5 * time.Minute, time.Second * 2).Should(gexec.Exit(0))
}

func findBlobstoreFiles(outerBoshBinaryPath string) ([]string, []string) {
	session, err := gexec.Start(exec.Command(outerBoshBinaryPath, "-d", "bosh", "ssh", "bosh", "-r", "--column", "stdout",
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
