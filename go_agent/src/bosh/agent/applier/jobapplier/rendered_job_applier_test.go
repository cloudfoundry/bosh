package jobapplier_test

import (
	"errors"
	"os"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
	"github.com/stretchr/testify/assert"

	fakebc "bosh/agent/applier/bundlecollection/fakes"
	. "bosh/agent/applier/jobapplier"
	models "bosh/agent/applier/models"
	fakeblob "bosh/blobstore/fakes"
	fakejobsuper "bosh/jobsupervisor/fakes"
	fakecmd "bosh/platform/commands/fakes"
	fakesys "bosh/system/fakes"
)

func init() {
	Describe("renderedJobApplier", func() {
		var (
			jobsBc        *fakebc.FakeBundleCollection
			blobstore     *fakeblob.FakeBlobstore
			compressor    *fakecmd.FakeCompressor
			jobSupervisor *fakejobsuper.FakeJobSupervisor
			applier       JobApplier
		)

		BeforeEach(func() {
			jobsBc = fakebc.NewFakeBundleCollection()
			blobstore = fakeblob.NewFakeBlobstore()
			compressor = fakecmd.NewFakeCompressor()
			jobSupervisor = fakejobsuper.NewFakeJobSupervisor()
			applier = NewRenderedJobApplier(jobsBc, blobstore, compressor, jobSupervisor)
		})

		Describe("Apply", func() {
			var (
				job    models.Job
				bundle *fakebc.FakeBundle
			)

			BeforeEach(func() {
				job = models.Job{
					Name:    "fake-job-name",
					Version: "fake-job-version",
				}
				bundle = jobsBc.FakeGet(job)
			})

			It("installs and enables job", func() {
				fs := fakesys.NewFakeFileSystem()
				bundle.InstallFs = fs
				bundle.InstallPath = "fake-install-dir"
				fs.MkdirAll("fake-install-dir", os.FileMode(0))

				err := applier.Apply(job)
				Expect(err).ToNot(HaveOccurred())
				Expect(bundle.Installed).To(BeTrue())
				Expect(bundle.Enabled).To(BeTrue())
			})

			It("errs when job install fails", func() {
				bundle.InstallError = errors.New("fake-install-error")

				err := applier.Apply(job)
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("fake-install-error"))
			})

			It("errs when job enable fails", func() {
				fs := fakesys.NewFakeFileSystem()
				bundle.InstallFs = fs
				bundle.InstallPath = "fake-install-dir"
				fs.MkdirAll("fake-install-dir", os.FileMode(0))

				bundle.EnableError = errors.New("fake-enable-error")

				err := applier.Apply(job)
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("fake-enable-error"))
			})

			It("downloads and cleans up job", func() {
				job.Source.BlobstoreId = "fake-blobstore-id"
				job.Source.Sha1 = "blob-sha1"

				fs := fakesys.NewFakeFileSystem()
				bundle.InstallFs = fs
				bundle.InstallPath = "fake-install-dir"
				fs.MkdirAll("fake-install-dir", os.FileMode(0))

				blobstore.GetFileName = "/dev/null"

				err := applier.Apply(job)
				Expect(err).ToNot(HaveOccurred())
				Expect("fake-blobstore-id").To(Equal(blobstore.GetBlobIds[0]))
				Expect("blob-sha1").To(Equal(blobstore.GetFingerprints[0]))
				Expect(blobstore.GetFileName).To(Equal(blobstore.CleanUpFileName))
			})

			It("errs when job download errs", func() {
				blobstore.GetError = errors.New("fake-get-error")

				err := applier.Apply(job)
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("fake-get-error"))
			})

			It("decompresses job to tmp path and cleans it up", func() {
				fs := fakesys.NewFakeFileSystem()
				fs.TempDirDir = "fake-tmp-dir"
				fs.MkdirAll("fake-tmp-dir", os.FileMode(0))

				bundle.InstallFs = fs
				bundle.InstallPath = "fake-install-dir"
				fs.MkdirAll("fake-install-dir", os.FileMode(0))

				blobstore.GetFileName = "/dev/null"

				err := applier.Apply(job)
				Expect(err).ToNot(HaveOccurred())
				Expect(blobstore.GetFileName).To(Equal(compressor.DecompressFileToDirTarballPaths[0]))
				Expect("fake-tmp-dir").To(Equal(compressor.DecompressFileToDirDirs[0]))
				assert.Nil(GinkgoT(), fs.GetFileTestStat(fs.TempDirDir))
			})

			It("errs when temp dir errs", func() {
				fs := fakesys.NewFakeFileSystem()
				fs.TempDirError = errors.New("fake-filesystem-tempdir-error")
				bundle.InstallFs = fs

				blobstore.GetFileName = "/dev/null"

				err := applier.Apply(job)
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("fake-filesystem-tempdir-error"))
			})

			It("errs when job decompress errs", func() {
				compressor.DecompressFileToDirError = errors.New("fake-decompress-error")

				fs := fakesys.NewFakeFileSystem()
				bundle.InstallFs = fs

				err := applier.Apply(job)
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("fake-decompress-error"))
			})

			It("copies from decompressed tmp path to install path", func() {
				job.Source.PathInArchive = "fake-path-in-archive"

				fs := fakesys.NewFakeFileSystem()
				fs.TempDirDir = "fake-tmp-dir"
				fs.MkdirAll("fake-tmp-dir", os.FileMode(0))

				bundle.InstallFs = fs
				bundle.InstallPath = "fake-install-dir"
				fs.MkdirAll("fake-install-dir", os.FileMode(0))

				blobstore.GetFileName = "/dev/null"

				compressor.DecompressFileToDirCallBack = func() {
					fs.MkdirAll("fake-tmp-dir/fake-path-in-archive", os.FileMode(0))
					fs.WriteFileString("fake-tmp-dir/fake-path-in-archive/file", "file-contents")
				}

				err := applier.Apply(job)
				Expect(err).ToNot(HaveOccurred())
				fileInArchiveStat := fs.GetFileTestStat("fake-install-dir/file")
				Expect(fileInArchiveStat).ToNot(BeNil())
				Expect([]byte("file-contents")).To(Equal(fileInArchiveStat.Content))
			})

			It("sets executable bit for files in bin", func() {
				job.Source.PathInArchive = "fake-path-in-archive"

				blobstore.GetFileName = "/dev/null"

				fs := fakesys.NewFakeFileSystem()
				fs.TempDirDir = "fake-tmp-dir"

				bundle.InstallFs = fs
				bundle.InstallPath = "fake-install-dir"

				compressor.DecompressFileToDirCallBack = func() {
					fs.WriteFile("fake-tmp-dir/fake-path-in-archive/bin/test1", []byte{})
					fs.WriteFile("fake-tmp-dir/fake-path-in-archive/bin/test2", []byte{})
					fs.WriteFile("fake-tmp-dir/fake-path-in-archive/config/test", []byte{})
				}

				fs.SetGlob("fake-install-dir/bin/*", []string{"fake-install-dir/bin/test1", "fake-install-dir/bin/test2"})

				err := applier.Apply(job)
				Expect(err).ToNot(HaveOccurred())

				testBin1Stats := fs.GetFileTestStat("fake-install-dir/bin/test1")
				Expect(testBin1Stats).ToNot(BeNil())
				Expect(0755).To(Equal(int(testBin1Stats.FileMode)))

				testBin2Stats := fs.GetFileTestStat("fake-install-dir/bin/test2")
				Expect(testBin2Stats).ToNot(BeNil())
				Expect(0755).To(Equal(int(testBin2Stats.FileMode)))

				testConfigStats := fs.GetFileTestStat("fake-install-dir/config/test")
				Expect(testConfigStats).ToNot(BeNil())
				assert.NotEqual(GinkgoT(), 0755, int(testConfigStats.FileMode))
			})

			It("errs when copy all errs", func() {
				fs := fakesys.NewFakeFileSystem()
				fs.TempDirDir = "fake-tmp-dir"
				fs.CopyDirEntriesError = errors.New("fake-copy-dir-entries-error")

				bundle.InstallFs = fs

				blobstore.GetFileName = "/dev/null"

				err := applier.Apply(job)
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("fake-copy-dir-entries-error"))
			})
		})

		Describe("Configure", func() {
			var (
				job    models.Job
				bundle *fakebc.FakeBundle
			)

			BeforeEach(func() {
				job = models.Job{
					Name:    "fake-job-name",
					Version: "fake-job-version",
				}
				bundle = jobsBc.FakeGet(job)
			})

			It("configure", func() {
				fs := fakesys.NewFakeFileSystem()
				fs.WriteFileString("/path/to/job/monit", "some conf")
				fs.SetGlob("/path/to/job/*.monit", []string{"/path/to/job/subjob.monit"})

				bundle.GetDirPath = "/path/to/job"
				bundle.GetDirFs = fs

				err := applier.Configure(job, 0)
				Expect(err).ToNot(HaveOccurred())

				Expect(2).To(Equal(len(jobSupervisor.AddJobArgs)))

				firstArgs := fakejobsuper.AddJobArgs{
					Name:       job.Name,
					Index:      0,
					ConfigPath: "/path/to/job/monit",
				}

				secondArgs := fakejobsuper.AddJobArgs{
					Name:       job.Name + "_subjob",
					Index:      0,
					ConfigPath: "/path/to/job/subjob.monit",
				}
				Expect(firstArgs).To(Equal(jobSupervisor.AddJobArgs[0]))
				Expect(secondArgs).To(Equal(jobSupervisor.AddJobArgs[1]))
			})
		})
	})
}
