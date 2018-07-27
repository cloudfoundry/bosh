package bbr_test

import (
	"io/ioutil"

	bratsutils "github.com/cloudfoundry/bosh-release-acceptance-tests/brats-utils"
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"

	"github.com/onsi/gomega/gbytes"
	"github.com/onsi/gomega/gexec"
)

var _ = Describe("Bosh Backup and Restore BBR", func() {
	var (
		backupDir             []string
		startInnerBoshOptions []string
		dbConfig              *bratsutils.ExternalDBConfig
		tmpCertDir            string
	)

	BeforeEach(func() {
		var err error
		tmpCertDir, err = ioutil.TempDir("", "db_tls")
		Expect(err).ToNot(HaveOccurred())

		dbConfig = nil

		startInnerBoshOptions = []string{
			fmt.Sprintf("-o %s", bratsutils.BoshDeploymentAssetPath("bbr.yml")),
			fmt.Sprintf("-o %s", bratsutils.AssetPath("latest-bbr-release.yml")),
		}
	})

	JustBeforeEach(func() {
		bratsutils.StartInnerBosh(startInnerBoshOptions...)
	})

	AfterEach(func() {
		for _, dir := range backupDir {
			err := os.RemoveAll(dir)
			Expect(err).ToNot(HaveOccurred())
		}
		bratsutils.StopInnerBosh()
		bratsutils.DeleteDB(dbConfig)
	})

	Context("database backup", func() {
		It("can backup and restore (removes underlying deployment and release)", func() {
			syslogManifestPath := bratsutils.AssetPath("syslog-manifest.yml")
			osConfManifestPath := bratsutils.AssetPath("os-conf-manifest.yml")

			By("create syslog deployment", func() {
				bratsutils.UploadStemcell(candidateWardenLinuxStemcellPath)
				bratsutils.UploadRelease("https://bosh.io/d/github.com/cloudfoundry/syslog-release?v=11")

				session := bratsutils.Bosh("-n", "deploy", syslogManifestPath,
					"-d", "syslog-deployment",
					"-v", fmt.Sprintf("stemcell-os=%s", bratsutils.StemcellOS()),
				)
				Eventually(session, 10*time.Minute).Should(gexec.Exit(0))
			})

			By("create os-conf deployment", func() {
				bratsutils.UploadRelease("https://bosh.io/d/github.com/cloudfoundry/os-conf-release?v=12")

				session := bratsutils.Bosh("-n", "deploy", osConfManifestPath,
					"-d", "os-conf-deployment",
					"-v", fmt.Sprintf("stemcell-os=%s", bratsutils.StemcellOS()),
				)
				Eventually(session, 10*time.Minute).Should(gexec.Exit(0))
			})

			By("bbr creates a backup", func() {
				session := bbr("director",
					"--host", fmt.Sprintf("%s:22", bratsutils.InnerDirectorIP()),
					"--username", bratsutils.InnerDirectorUser(),
					"--private-key-path", bratsutils.InnerBoshJumpboxPrivateKeyPath(),
					"backup")
				Eventually(session, 10*time.Minute).Should(gexec.Exit(0))
			})

			By("wipe system, recreate inner director", func() {
				bratsutils.StopInnerBosh()
				bratsutils.StartInnerBosh(startInnerBoshOptions...)
			})

			By("expect deploy to fail because the release/stemcell won't be there", func() {
				session := bratsutils.Bosh("-n", "deploy", syslogManifestPath,
					"-d", "syslog-deployment",
					"-v", fmt.Sprintf("stemcell-os=%s", bratsutils.StemcellOS()),
					"--recreate",
				)
				Eventually(session, time.Minute).Should(gexec.Exit(1))
			})

			By("restore inner director from backup", func() {
				backupDir = getBackupDir()
				Expect(backupDir).To(HaveLen(1))

				session := bbr("director",
					"--host", fmt.Sprintf("%s:22", bratsutils.InnerDirectorIP()),
					"--username", bratsutils.InnerDirectorUser(),
					"--private-key-path", bratsutils.InnerBoshJumpboxPrivateKeyPath(),
					"restore",
					"--artifact-path", backupDir[0])
				Eventually(session, 2*time.Minute).Should(gexec.Exit(0))

				waitForBoshDirectorUp(bratsutils.BoshBinaryPath())

				session = bratsutils.Bosh("-n", "upload-stemcell", "--fix", candidateWardenLinuxStemcellPath)
				Eventually(session, 5*time.Minute).Should(gexec.Exit(0))
			})

			By("cck the deployments", func() {
				session := bratsutils.Bosh("-n", "-d", "syslog-deployment", "cck", "--auto")
				Eventually(session, 10*time.Minute).Should(gexec.Exit(0))

				session = bratsutils.Bosh("-n", "-d", "os-conf-deployment", "cck",
					"--resolution", "delete_vm_reference",
					"--resolution", "delete_disk_reference")
				Eventually(session, 10*time.Minute).Should(gexec.Exit(0))

				session = bratsutils.Bosh("-n", "deploy", osConfManifestPath,
					"-d", "os-conf-deployment",
					"-v", fmt.Sprintf("stemcell-os=%s", bratsutils.StemcellOS()),
				)
				Eventually(session, 10*time.Minute).Should(gexec.Exit(0))
			})

			By("validate deployments", func() {
				By("instance actually ran the jobs", func() {
					session := bratsutils.Bosh("-n", "-d", "syslog-deployment", "instances",
						"--ps",
						"--column=process_state",
						"--column=instance")
					Eventually(session, time.Minute).Should(gexec.Exit(0))

					Expect(session.Out.Contents()).To(MatchRegexp("syslog_storer/[a-z0-9-]+[ \t]+running"))
					Expect(session.Out.Contents()).To(MatchRegexp("syslog_forwarder/[a-z0-9-]+[ \t]+running"))
				})

				By("persistent disks exist", func() {
					session := bratsutils.Bosh("-n", "-d", "os-conf-deployment", "instances",
						"--details",
						"--column", "disk_cids",
					)

					Eventually(session, time.Minute).Should(gexec.Exit(0))
					Expect(string(session.Out.Contents())).To(MatchRegexp("[0-9a-f]{8}-[0-9a-f-]{27}"))
				})
			})
		})

		It("can backup and restore (reattaches to underlying deployment)", func() {
			By("Set up a deployment that uses the syslog release", func() {
				bratsutils.UploadStemcell(candidateWardenLinuxStemcellPath)
				bratsutils.UploadRelease("https://bosh.io/d/github.com/cloudfoundry/syslog-release?v=11")

				manifestPath := bratsutils.AssetPath("syslog-manifest.yml")
				session := bratsutils.Bosh("-n", "deploy", manifestPath,
					"-d", "syslog-deployment",
					"-v", fmt.Sprintf("stemcell-os=%s", bratsutils.StemcellOS()),
				)

				Eventually(session, 10*time.Minute).Should(gexec.Exit(0))
			})

			By("bbr creates a backup", func() {
				session := bbr("director",
					"--host", fmt.Sprintf("%s:22", bratsutils.InnerDirectorIP()),
					"--username", bratsutils.InnerDirectorUser(),
					"--private-key-path", bratsutils.InnerBoshJumpboxPrivateKeyPath(),
					"backup")
				Eventually(session, time.Minute).Should(gexec.Exit(0))
			})

			By("wipe system", func() {
				session := bratsutils.OuterBosh("-d", bratsutils.InnerBoshDirectorName(),
					"ssh", "bosh", "sudo rm -rf /var/vcap/store/blobstore/*")
				Eventually(session, 5*time.Minute).Should(gexec.Exit(0))

				backupDir = getBackupDir()
				Expect(backupDir).To(HaveLen(1))

				session = bbr("director",
					"--host", fmt.Sprintf("%s:22", bratsutils.InnerDirectorIP()),
					"--username", bratsutils.InnerDirectorUser(),
					"--private-key-path", bratsutils.InnerBoshJumpboxPrivateKeyPath(),
					"restore",
					"--artifact-path", backupDir[0])
				Eventually(session, time.Minute).Should(gexec.Exit(0))

				waitForBoshDirectorUp(bratsutils.BoshBinaryPath())

				session = bratsutils.Bosh("-n", "upload-stemcell", "--fix", candidateWardenLinuxStemcellPath)
				Eventually(session, 5*time.Minute).Should(gexec.Exit(0))

				session = bratsutils.Bosh("-n", "-d", "syslog-deployment", "cck", "--report")
				Eventually(session, 10*time.Minute).Should(gexec.Exit(0))
			})

			By("validate deployment. instance actually ran the jobs", func() {
				session := bratsutils.Bosh("-n", "-d", "syslog-deployment", "instances",
					"--ps",
					"--column=process_state",
					"--column=instance",
				)
				Eventually(session, time.Minute).Should(gexec.Exit(0))

				Expect(session.Out.Contents()).To(MatchRegexp("syslog_storer/[a-z0-9-]+[ \t]+running"))
				Expect(session.Out.Contents()).To(MatchRegexp("syslog_forwarder/[a-z0-9-]+[ \t]+running"))
			})
		})

		Context("TLS configuration", func() {
			backUpAndRestores := func() {
				It("backs up and restores", func() {
					syslogManifestPath := bratsutils.AssetPath("syslog-manifest.yml")
					bratsutils.UploadStemcell(candidateWardenLinuxStemcellPath)

					By("create syslog deployment", func() {
						bratsutils.UploadRelease("https://bosh.io/d/github.com/cloudfoundry/syslog-release?v=11")

						session := bratsutils.Bosh("-n", "deploy", syslogManifestPath,
							"-d", "syslog-deployment",
							"-v", fmt.Sprintf("stemcell-os=%s", bratsutils.StemcellOS()),
						)
						Eventually(session, 5*time.Minute).Should(gexec.Exit(0))
					})

					By("creating a backup", func() {
						session := bbr("director",
							"--host", fmt.Sprintf("%s:22", bratsutils.InnerDirectorIP()),
							"--username", bratsutils.InnerDirectorUser(),
							"--private-key-path", bratsutils.InnerBoshJumpboxPrivateKeyPath(),
							"backup")
						Eventually(session, 2*time.Minute).Should(gexec.Exit(0))
					})

					By("deleting the deployment (whoops)", func() {
						session := bratsutils.Bosh("-n", "delete-deployment", "-d", "syslog-deployment", "--force")
						Eventually(session, 10*time.Minute).Should(gexec.Exit(0))
					})

					By("restore inner director from backup", func() {
						backupDir = getBackupDir()
						Expect(backupDir).To(HaveLen(1))

						session := bbr("director",
							"--host", fmt.Sprintf("%s:22", bratsutils.InnerDirectorIP()),
							"--username", bratsutils.InnerDirectorUser(),
							"--private-key-path", bratsutils.InnerBoshJumpboxPrivateKeyPath(),
							"restore",
							"--artifact-path", backupDir[0])
						Eventually(session, 2*time.Minute).Should(gexec.Exit(0))

						waitForBoshDirectorUp(bratsutils.BoshBinaryPath())
					})

					By("verifying that the deployment still exists", func() {
						session := bratsutils.Bosh("-n", "deployments")
						Eventually(session, time.Minute).Should(gexec.Exit(0))
						Eventually(session).Should(gbytes.Say("syslog-deployment"))
					})
				})
			}

			Context("RDS", func() {
				Context("Mysql", func() {
					BeforeEach(func() {
						dbConfig = bratsutils.LoadExternalDBConfig("rds_mysql", false, tmpCertDir)
						bratsutils.CreateDB(dbConfig)

						startInnerBoshOptions = append(startInnerBoshOptions, bratsutils.InnerBoshWithExternalDBOptions(dbConfig)...)
					})

					backUpAndRestores()
				})

				Context("Postgres", func() {
					BeforeEach(func() {
						dbConfig = bratsutils.LoadExternalDBConfig("rds_postgres", false, tmpCertDir)
						bratsutils.CreateDB(dbConfig)

						startInnerBoshOptions = append(startInnerBoshOptions, bratsutils.InnerBoshWithExternalDBOptions(dbConfig)...)
					})

					backUpAndRestores()
				})
			})

			Context("Google Cloud SQL", func() {
				Context("Mysql", func() {
					BeforeEach(func() {
						dbConfig = bratsutils.LoadExternalDBConfig("gcp_mysql", true, tmpCertDir)
						bratsutils.CreateDB(dbConfig)

						startInnerBoshOptions = append(startInnerBoshOptions, bratsutils.InnerBoshWithExternalDBOptions(dbConfig)...)
					})

					backUpAndRestores()
				})

				Context("Postgres", func() {
					BeforeEach(func() {
						dbConfig = bratsutils.LoadExternalDBConfig("gcp_postgres", true, tmpCertDir)
						bratsutils.CreateDB(dbConfig)

						startInnerBoshOptions = append(startInnerBoshOptions, bratsutils.InnerBoshWithExternalDBOptions(dbConfig)...)
					})

					backUpAndRestores()
				})
			})
		})

		Context("blobstore files", func() {
			var directoriesBefore, filesBefore []string

			It("backs up an empty blobstore", func() {
				By("Backup deployment", func() {
					session := bbr("director",
						"--host", fmt.Sprintf("%s:22", bratsutils.InnerDirectorIP()),
						"--username", bratsutils.InnerDirectorUser(),
						"--private-key-path", bratsutils.InnerBoshJumpboxPrivateKeyPath(),
						"backup")
					Eventually(session, time.Minute).Should(gexec.Exit(0))
				})

				By("Restore deployment", func() {
					backupDir = getBackupDir()
					Expect(backupDir).To(HaveLen(1))

					session := bbr("director",
						"--host", fmt.Sprintf("%s:22", bratsutils.InnerDirectorIP()),
						"--username", bratsutils.InnerDirectorUser(),
						"--private-key-path", bratsutils.InnerBoshJumpboxPrivateKeyPath(),
						"restore",
						"--artifact-path", backupDir[0])
					Eventually(session, time.Minute).Should(gexec.Exit(0))

					waitForBoshDirectorUp(bratsutils.BoshBinaryPath())
				})
			})

			It("restores the blobstore files with the correct permissions/ownership", func() {
				By("Upload a release", func() {
					bratsutils.UploadRelease("https://bosh.io/d/github.com/cloudfoundry/syslog-release?v=11")
				})

				By("Store directory/file structure before we do backup", func() {
					directoriesBefore, filesBefore = findBlobstoreFiles(bratsutils.OuterBoshBinaryPath())
				})

				By("Backup deployment", func() {
					session := bbr("director",
						"--host", fmt.Sprintf("%s:22", bratsutils.InnerDirectorIP()),
						"--username", bratsutils.InnerDirectorUser(),
						"--private-key-path", bratsutils.InnerBoshJumpboxPrivateKeyPath(),
						"backup")
					Eventually(session, time.Minute).Should(gexec.Exit(0))
				})

				By("Check directories are still there after backup", func() {
					directoriesAfter, filesAfter := findBlobstoreFiles(bratsutils.OuterBoshBinaryPath())
					Expect(directoriesAfter).To(Equal(directoriesBefore))
					Expect(filesAfter).To(Equal(filesBefore))
				})

				By("\"wipe\" system", func() {
					session := bratsutils.OuterBosh("-d", bratsutils.InnerBoshDirectorName(), "ssh", "bosh", "-c", "sudo rm -rf /var/vcap/store/blobstore/*")
					Eventually(session, 5*time.Minute).Should(gexec.Exit(0))
				})

				By("Restore deployment", func() {
					backupDir = getBackupDir()
					Expect(backupDir).To(HaveLen(1))

					session := bbr("director",
						"--host", fmt.Sprintf("%s:22", bratsutils.InnerDirectorIP()),
						"--username", bratsutils.InnerDirectorUser(),
						"--private-key-path", bratsutils.InnerBoshJumpboxPrivateKeyPath(),
						"restore",
						"--artifact-path", backupDir[0])
					Eventually(session, time.Minute).Should(gexec.Exit(0))

					waitForBoshDirectorUp(bratsutils.BoshBinaryPath())
				})

				By("Check directories have correct permissions after restore", func() {
					directoriesAfter, filesAfter := findBlobstoreFiles(bratsutils.OuterBoshBinaryPath())
					Expect(directoriesAfter).To(Equal(directoriesBefore))
					Expect(filesAfter).To(Equal(filesBefore))
				})
			})
		})
	})
})

func getBackupDir() []string {
	backupDir, err := filepath.Glob(fmt.Sprintf("%s_*", bratsutils.InnerDirectorIP()))
	Expect(err).NotTo(HaveOccurred())
	return backupDir
}

func waitForBoshDirectorUp(boshBinaryPath string) {
	Eventually(func() *gexec.Session {
		session := bratsutils.Bosh("env")
		session.Wait(time.Minute)
		return session
	}, 5*time.Minute, 2*time.Second).Should(gexec.Exit(0))
}

func findBlobstoreFiles(outerBoshBinaryPath string) ([]string, []string) {
	session := bratsutils.OuterBosh("-d", bratsutils.InnerBoshDirectorName(), "ssh", "bosh", "--results", "--column", "stdout",
		"sudo find /var/vcap/store/blobstore/store -type d -perm 0700 -user vcap -group vcap")
	Eventually(session, time.Minute).Should(gexec.Exit(0))

	directories := strings.Split(string(session.Out.Contents()), "\n")
	sort.Strings(directories)

	session = bratsutils.OuterBosh("-d", bratsutils.InnerBoshDirectorName(), "ssh", "bosh", "-r", "--column", "stdout",
		"sudo find /var/vcap/store/blobstore/store -type f -perm 0600 -user vcap -group vcap")
	Eventually(session, time.Minute).Should(gexec.Exit(0))

	files := strings.Split(string(session.Out.Contents()), "\n")
	sort.Strings(files)

	return directories, files
}
