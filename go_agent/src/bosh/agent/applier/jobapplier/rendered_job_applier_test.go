package jobapplier_test

import (
	"errors"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	boshbc "bosh/agent/applier/bundlecollection"
	fakebc "bosh/agent/applier/bundlecollection/fakes"
	. "bosh/agent/applier/jobapplier"
	models "bosh/agent/applier/models"
	fakepa "bosh/agent/applier/packageapplier/fakes"
	fakeblob "bosh/blobstore/fakes"
	fakejobsuper "bosh/jobsupervisor/fakes"
	boshlog "bosh/logger"
	fakecmd "bosh/platform/commands/fakes"
	fakesys "bosh/system/fakes"
	boshuuid "bosh/uuid"
)

func buildJob(bc *fakebc.FakeBundleCollection) (models.Job, *fakebc.FakeBundle) {
	uuidGen := boshuuid.NewGenerator()
	uuid, err := uuidGen.Generate()
	Expect(err).ToNot(HaveOccurred())

	job := models.Job{
		Name:    "fake-job-name" + uuid,
		Version: "fake-job-version",
		Source: models.Source{
			Sha1:          "fake-blob-sha1",
			BlobstoreID:   "fake-blobstore-id",
			PathInArchive: "fake-path-in-archive",
		},
		Packages: []models.Package{
			models.Package{
				Name:    "fake-package1-name" + uuid,
				Version: "fake-package1-version",
				Source: models.Source{
					Sha1:          "fake-package1-sha1",
					BlobstoreID:   "fake-package1-blobstore-id",
					PathInArchive: "",
				},
			},
			models.Package{
				Name:    "fake-package2-name" + uuid,
				Version: "fake-package2-version",
				Source: models.Source{
					Sha1:          "fake-package2-sha1",
					BlobstoreID:   "fake-package2-blobstore-id",
					PathInArchive: "",
				},
			},
		},
	}

	bundle := bc.FakeGet(job)

	return job, bundle
}

func init() {
	Describe("renderedJobApplier", func() {
		var (
			jobsBc                 *fakebc.FakeBundleCollection
			jobSupervisor          *fakejobsuper.FakeJobSupervisor
			packageApplierProvider *fakepa.FakePackageApplierProvider
			blobstore              *fakeblob.FakeBlobstore
			compressor             *fakecmd.FakeCompressor
			fs                     *fakesys.FakeFileSystem
			applier                JobApplier
		)

		BeforeEach(func() {
			jobsBc = fakebc.NewFakeBundleCollection()
			jobSupervisor = fakejobsuper.NewFakeJobSupervisor()
			packageApplierProvider = fakepa.NewFakePackageApplierProvider()
			blobstore = fakeblob.NewFakeBlobstore()
			fs = fakesys.NewFakeFileSystem()
			compressor = fakecmd.NewFakeCompressor()
			logger := boshlog.NewLogger(boshlog.LevelNone)
			applier = NewRenderedJobApplier(
				jobsBc,
				jobSupervisor,
				packageApplierProvider,
				blobstore,
				compressor,
				fs,
				logger,
			)
		})

		Describe("Prepare & Apply", func() {
			var (
				job    models.Job
				bundle *fakebc.FakeBundle
			)

			BeforeEach(func() {
				job, bundle = buildJob(jobsBc)
			})

			ItInstallsJob := func(act func() error) {
				It("returns error when installing job fails", func() {
					bundle.InstallError = errors.New("fake-install-error")

					err := act()
					Expect(err).To(HaveOccurred())
					Expect(err.Error()).To(ContainSubstring("fake-install-error"))
				})

				It("downloads and later cleans up downloaded job template blob", func() {
					blobstore.GetFileName = "/fake-blobstore-file-name"

					err := act()
					Expect(err).ToNot(HaveOccurred())
					Expect(blobstore.GetBlobIDs[0]).To(Equal("fake-blobstore-id"))
					Expect(blobstore.GetFingerprints[0]).To(Equal("fake-blob-sha1"))

					// downloaded file is cleaned up
					Expect(blobstore.CleanUpFileName).To(Equal("/fake-blobstore-file-name"))
				})

				It("returns error when downloading job template blob fails", func() {
					blobstore.GetError = errors.New("fake-get-error")

					err := act()
					Expect(err).To(HaveOccurred())
					Expect(err.Error()).To(ContainSubstring("fake-get-error"))
				})

				It("decompresses job template blob to tmp path and later cleans it up", func() {
					fs.TempDirDir = "/fake-tmp-dir"
					blobstore.GetFileName = "/fake-blobstore-file-name"

					var tmpDirExistsBeforeInstall bool

					bundle.InstallCallBack = func() {
						tmpDirExistsBeforeInstall = true
					}

					err := act()
					Expect(err).ToNot(HaveOccurred())

					Expect(compressor.DecompressFileToDirTarballPaths[0]).To(Equal("/fake-blobstore-file-name"))
					Expect(compressor.DecompressFileToDirDirs[0]).To(Equal("/fake-tmp-dir"))

					// tmp dir exists before bundle install
					Expect(tmpDirExistsBeforeInstall).To(BeTrue())

					// tmp dir is cleaned up after install
					Expect(fs.FileExists(fs.TempDirDir)).To(BeFalse())
				})

				It("returns error when temporary directory creation fails", func() {
					fs.TempDirError = errors.New("fake-filesystem-tempdir-error")

					err := act()
					Expect(err).To(HaveOccurred())
					Expect(err.Error()).To(ContainSubstring("fake-filesystem-tempdir-error"))
				})

				It("returns error when decompressing job template fails", func() {
					compressor.DecompressFileToDirErr = errors.New("fake-decompress-error")

					err := act()
					Expect(err).To(HaveOccurred())
					Expect(err.Error()).To(ContainSubstring("fake-decompress-error"))
				})

				It("returns error when getting the list of bin files fails", func() {
					fs.GlobErr = errors.New("fake-glob-error")

					err := act()
					Expect(err).To(HaveOccurred())
					Expect(err.Error()).To(ContainSubstring("fake-glob-error"))
				})

				It("returns error when changing permissions on bin files fails", func() {
					fs.TempDirDir = "/fake-tmp-dir"

					fs.SetGlob("/fake-tmp-dir/fake-path-in-archive/bin/*", []string{
						"/fake-tmp-dir/fake-path-in-archive/bin/test",
					})

					fs.ChmodErr = errors.New("fake-chmod-error")

					err := act()
					Expect(err).To(HaveOccurred())
					Expect(err.Error()).To(ContainSubstring("fake-chmod-error"))
				})

				It("installs bundle from decompressed tmp path of a job template", func() {
					fs.TempDirDir = "/fake-tmp-dir"

					var installedBeforeDecompression bool

					compressor.DecompressFileToDirCallBack = func() {
						installedBeforeDecompression = bundle.Installed
					}

					err := act()
					Expect(err).ToNot(HaveOccurred())

					// bundle installation did not happen before decompression
					Expect(installedBeforeDecompression).To(BeFalse())

					// make sure that bundle install happened after decompression
					Expect(bundle.InstallSourcePath).To(Equal("/fake-tmp-dir/fake-path-in-archive"))
				})

				It("sets executable bit for files in bin", func() {
					fs.TempDirDir = "/fake-tmp-dir"

					compressor.DecompressFileToDirCallBack = func() {
						fs.WriteFile("/fake-tmp-dir/fake-path-in-archive/bin/test1", []byte{})
						fs.WriteFile("/fake-tmp-dir/fake-path-in-archive/bin/test2", []byte{})
						fs.WriteFile("/fake-tmp-dir/fake-path-in-archive/config/test", []byte{})
					}

					fs.SetGlob("/fake-tmp-dir/fake-path-in-archive/bin/*", []string{
						"/fake-tmp-dir/fake-path-in-archive/bin/test1",
						"/fake-tmp-dir/fake-path-in-archive/bin/test2",
					})

					var binTest1Stats, binTest2Stats, configTestStats *fakesys.FakeFileStats

					bundle.InstallCallBack = func() {
						binTest1Stats = fs.GetFileTestStat("/fake-tmp-dir/fake-path-in-archive/bin/test1")
						binTest2Stats = fs.GetFileTestStat("/fake-tmp-dir/fake-path-in-archive/bin/test2")
						configTestStats = fs.GetFileTestStat("/fake-tmp-dir/fake-path-in-archive/config/test")
					}

					err := act()
					Expect(err).ToNot(HaveOccurred())

					// bin files are executable
					Expect(int(binTest1Stats.FileMode)).To(Equal(0755))
					Expect(int(binTest2Stats.FileMode)).To(Equal(0755))

					// non-bin files are not made executable
					Expect(int(configTestStats.FileMode)).ToNot(Equal(0755))
				})
			}

			ItUpdatesPackages := func(act func() error) {
				var packageApplier *fakepa.FakePackageApplier

				BeforeEach(func() {
					packageApplier = fakepa.NewFakePackageApplier()
					packageApplierProvider.JobSpecificPackageAppliers[job.Name] = packageApplier
				})

				It("applies each package that job depends on and then cleans up packages", func() {
					err := act()
					Expect(err).ToNot(HaveOccurred())
					Expect(packageApplier.ActionsCalled).To(Equal([]string{"Apply", "Apply", "KeepOnly"}))
					Expect(len(packageApplier.AppliedPackages)).To(Equal(2)) // present
					Expect(packageApplier.AppliedPackages).To(Equal(job.Packages))
				})

				It("returns error when applying package that job depends on fails", func() {
					packageApplier.ApplyError = errors.New("fake-apply-err")

					err := act()
					Expect(err).To(HaveOccurred())
					Expect(err.Error()).To(ContainSubstring("fake-apply-err"))
				})

				It("keeps only currently required packages but does not completely uninstall them", func() {
					err := act()
					Expect(err).ToNot(HaveOccurred())
					Expect(len(packageApplier.KeptOnlyPackages)).To(Equal(2)) // present
					Expect(packageApplier.KeptOnlyPackages).To(Equal(job.Packages))
				})

				It("returns error when keeping only currently required packages fails", func() {
					packageApplier.KeepOnlyErr = errors.New("fake-keep-only-err")

					err := act()
					Expect(err).To(HaveOccurred())
					Expect(err.Error()).To(ContainSubstring("fake-keep-only-err"))
				})
			}

			Describe("Prepare", func() {
				act := func() error { return applier.Prepare(job) }

				It("return an error if getting file bundle fails", func() {
					jobsBc.GetErr = errors.New("fake-get-bundle-error")

					err := act()
					Expect(err).To(HaveOccurred())
					Expect(err.Error()).To(ContainSubstring("fake-get-bundle-error"))
				})

				It("returns an error if checking for installed path fails", func() {
					bundle.IsInstalledErr = errors.New("fake-is-installed-error")

					err := act()
					Expect(err).To(HaveOccurred())
					Expect(err.Error()).To(ContainSubstring("fake-is-installed-error"))
				})

				Context("when job is already installed", func() {
					BeforeEach(func() {
						bundle.Installed = true
					})

					It("does not install", func() {
						err := act()
						Expect(err).ToNot(HaveOccurred())
						Expect(bundle.ActionsCalled).To(Equal([]string{})) // no Install
					})

					It("does not download the job template", func() {
						err := act()
						Expect(err).ToNot(HaveOccurred())
						Expect(blobstore.GetBlobIDs).To(BeNil())
					})
				})

				Context("when job is not installed", func() {
					BeforeEach(func() {
						bundle.Installed = false
					})

					It("installs job (but does not enable)", func() {
						err := act()
						Expect(err).ToNot(HaveOccurred())
						Expect(bundle.ActionsCalled).To(Equal([]string{"Install"}))
					})

					ItInstallsJob(act)
				})
			})

			Describe("Apply", func() {
				act := func() error { return applier.Apply(job) }

				It("return an error if getting file bundle fails", func() {
					jobsBc.GetErr = errors.New("fake-get-bundle-error")

					err := act()
					Expect(err).To(HaveOccurred())
					Expect(err.Error()).To(ContainSubstring("fake-get-bundle-error"))
				})

				It("returns an error if checking for installed path fails", func() {
					bundle.IsInstalledErr = errors.New("fake-is-installed-error")

					err := act()
					Expect(err).To(HaveOccurred())
					Expect(err.Error()).To(ContainSubstring("fake-is-installed-error"))
				})

				Context("when job is already installed", func() {
					BeforeEach(func() {
						bundle.Installed = true
					})

					It("does not install but only enables job", func() {
						err := act()
						Expect(err).ToNot(HaveOccurred())
						Expect(bundle.ActionsCalled).To(Equal([]string{"Enable"})) // no Install
					})

					It("returns error when job enable fails", func() {
						bundle.EnableError = errors.New("fake-enable-error")

						err := act()
						Expect(err).To(HaveOccurred())
						Expect(err.Error()).To(ContainSubstring("fake-enable-error"))
					})

					It("does not download the job template", func() {
						err := act()
						Expect(err).ToNot(HaveOccurred())
						Expect(blobstore.GetBlobIDs).To(BeNil())
					})

					ItUpdatesPackages(act)
				})

				Context("when job is not installed", func() {
					BeforeEach(func() {
						bundle.Installed = false
					})

					It("installs and enables job", func() {
						err := act()
						Expect(err).ToNot(HaveOccurred())
						Expect(bundle.ActionsCalled).To(Equal([]string{"Install", "Enable"}))
					})

					It("returns error when job enable fails", func() {
						bundle.EnableError = errors.New("fake-enable-error")

						err := act()
						Expect(err).To(HaveOccurred())
						Expect(err.Error()).To(ContainSubstring("fake-enable-error"))
					})

					ItInstallsJob(act)

					ItUpdatesPackages(act)
				})
			})
		})

		Describe("Configure", func() {
			It("adds job to the job supervisor", func() {
				job, bundle := buildJob(jobsBc)

				fs := fakesys.NewFakeFileSystem()
				fs.WriteFileString("/path/to/job/monit", "some conf")
				fs.SetGlob("/path/to/job/*.monit", []string{"/path/to/job/subjob.monit"})

				bundle.GetDirPath = "/path/to/job"
				bundle.GetDirFs = fs

				err := applier.Configure(job, 0)
				Expect(err).ToNot(HaveOccurred())

				Expect(len(jobSupervisor.AddJobArgs)).To(Equal(2))

				Expect(jobSupervisor.AddJobArgs[0]).To(Equal(fakejobsuper.AddJobArgs{
					Name:       job.Name,
					Index:      0,
					ConfigPath: "/path/to/job/monit",
				}))

				Expect(jobSupervisor.AddJobArgs[1]).To(Equal(fakejobsuper.AddJobArgs{
					Name:       job.Name + "_subjob",
					Index:      0,
					ConfigPath: "/path/to/job/subjob.monit",
				}))
			})

			It("does not require monit script", func() {
				job, bundle := buildJob(jobsBc)

				fs := fakesys.NewFakeFileSystem()
				bundle.GetDirFs = fs

				err := applier.Configure(job, 0)
				Expect(err).ToNot(HaveOccurred())
				Expect(len(jobSupervisor.AddJobArgs)).To(Equal(0))
			})
		})

		Describe("KeepOnly", func() {
			It("first disables and then uninstalls jobs that are not in keeponly list", func() {
				_, bundle1 := buildJob(jobsBc)
				job2, bundle2 := buildJob(jobsBc)
				_, bundle3 := buildJob(jobsBc)
				job4, bundle4 := buildJob(jobsBc)

				jobsBc.ListBundles = []boshbc.Bundle{bundle1, bundle2, bundle3, bundle4}

				err := applier.KeepOnly([]models.Job{job4, job2})
				Expect(err).ToNot(HaveOccurred())

				Expect(bundle1.ActionsCalled).To(Equal([]string{"Disable", "Uninstall"}))
				Expect(bundle2.ActionsCalled).To(Equal([]string{}))
				Expect(bundle3.ActionsCalled).To(Equal([]string{"Disable", "Uninstall"}))
				Expect(bundle4.ActionsCalled).To(Equal([]string{}))
			})

			It("returns error when bundle collection fails to return list of installed bundles", func() {
				jobsBc.ListErr = errors.New("fake-bc-list-error")

				err := applier.KeepOnly([]models.Job{})
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("fake-bc-list-error"))
			})

			It("returns error when bundle collection cannot retrieve bundle for keep-only job", func() {
				job1, bundle1 := buildJob(jobsBc)

				jobsBc.ListBundles = []boshbc.Bundle{bundle1}
				jobsBc.GetErr = errors.New("fake-bc-get-error")

				err := applier.KeepOnly([]models.Job{job1})
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("fake-bc-get-error"))
			})

			It("returns error when at least one bundle cannot be disabled", func() {
				_, bundle1 := buildJob(jobsBc)

				jobsBc.ListBundles = []boshbc.Bundle{bundle1}
				bundle1.DisableErr = errors.New("fake-bc-disable-error")

				err := applier.KeepOnly([]models.Job{})
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("fake-bc-disable-error"))
			})

			It("returns error when at least one bundle cannot be uninstalled", func() {
				_, bundle1 := buildJob(jobsBc)

				jobsBc.ListBundles = []boshbc.Bundle{bundle1}
				bundle1.UninstallErr = errors.New("fake-bc-uninstall-error")

				err := applier.KeepOnly([]models.Job{})
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("fake-bc-uninstall-error"))
			})
		})
	})
}
