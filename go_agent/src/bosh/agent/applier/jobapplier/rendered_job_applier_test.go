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

func buildJobApplier() (
	jobsBc *fakebc.FakeBundleCollection,
	blobstore *fakeblob.FakeBlobstore,
	compressor *fakecmd.FakeCompressor,
	jobSupervisor *fakejobsuper.FakeJobSupervisor,
	applier JobApplier,
) {
	jobsBc = fakebc.NewFakeBundleCollection()
	blobstore = fakeblob.NewFakeBlobstore()
	compressor = fakecmd.NewFakeCompressor()
	jobSupervisor = fakejobsuper.NewFakeJobSupervisor()

	applier = NewRenderedJobApplier(jobsBc, blobstore, compressor, jobSupervisor)
	return
}

func buildJob(jobsBc *fakebc.FakeBundleCollection) (job models.Job, bundle *fakebc.FakeBundle) {
	job = models.Job{Name: "fake-job-name", Version: "fake-job-version"}
	bundle = jobsBc.FakeGet(job)
	return
}
func init() {
	Describe("Testing with Ginkgo", func() {
		It("apply installs and enables job", func() {
			jobsBc, _, _, _, applier := buildJobApplier()
			job, bundle := buildJob(jobsBc)

			fs := fakesys.NewFakeFileSystem()
			bundle.InstallFs = fs
			bundle.InstallPath = "fake-install-dir"
			fs.MkdirAll("fake-install-dir", os.FileMode(0))

			err := applier.Apply(job)
			Expect(err).ToNot(HaveOccurred())
			Expect(bundle.Installed).To(BeTrue())
			Expect(bundle.Enabled).To(BeTrue())
		})
		It("apply errs when job install fails", func() {

			jobsBc, _, _, _, applier := buildJobApplier()
			job, bundle := buildJob(jobsBc)

			bundle.InstallError = errors.New("fake-install-error")

			err := applier.Apply(job)
			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(ContainSubstring("fake-install-error"))
		})
		It("apply errs when job enable fails", func() {

			jobsBc, _, _, _, applier := buildJobApplier()
			job, bundle := buildJob(jobsBc)

			fs := fakesys.NewFakeFileSystem()
			bundle.InstallFs = fs
			bundle.InstallPath = "fake-install-dir"
			fs.MkdirAll("fake-install-dir", os.FileMode(0))

			bundle.EnableError = errors.New("fake-enable-error")

			err := applier.Apply(job)
			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(ContainSubstring("fake-enable-error"))
		})
		It("apply downloads and cleans up job", func() {

			jobsBc, blobstore, _, _, applier := buildJobApplier()
			job, bundle := buildJob(jobsBc)
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
		It("apply errs when job download errs", func() {

			jobsBc, blobstore, _, _, applier := buildJobApplier()
			job, _ := buildJob(jobsBc)

			blobstore.GetError = errors.New("fake-get-error")

			err := applier.Apply(job)
			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(ContainSubstring("fake-get-error"))
		})
		It("apply decompresses job to tmp path and cleans it up", func() {

			jobsBc, blobstore, compressor, _, applier := buildJobApplier()
			job, bundle := buildJob(jobsBc)

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
		It("apply errs when temp dir errs", func() {

			jobsBc, blobstore, _, _, applier := buildJobApplier()
			job, bundle := buildJob(jobsBc)

			fs := fakesys.NewFakeFileSystem()
			fs.TempDirError = errors.New("fake-filesystem-tempdir-error")
			bundle.InstallFs = fs

			blobstore.GetFileName = "/dev/null"

			err := applier.Apply(job)
			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(ContainSubstring("fake-filesystem-tempdir-error"))
		})
		It("apply errs when job decompress errs", func() {

			jobsBc, _, compressor, _, applier := buildJobApplier()
			job, bundle := buildJob(jobsBc)

			compressor.DecompressFileToDirError = errors.New("fake-decompress-error")

			fs := fakesys.NewFakeFileSystem()
			bundle.InstallFs = fs

			err := applier.Apply(job)
			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(ContainSubstring("fake-decompress-error"))
		})
		It("apply copies from decompressed tmp path to install path", func() {

			jobsBc, blobstore, compressor, _, applier := buildJobApplier()
			job, bundle := buildJob(jobsBc)
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
		It("apply sets executable bit for files in bin", func() {

			jobsBc, blobstore, compressor, _, applier := buildJobApplier()
			job, bundle := buildJob(jobsBc)
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
		It("apply errs when copy all errs", func() {

			jobsBc, blobstore, _, _, applier := buildJobApplier()
			job, bundle := buildJob(jobsBc)

			fs := fakesys.NewFakeFileSystem()
			fs.TempDirDir = "fake-tmp-dir"
			fs.CopyDirEntriesError = errors.New("fake-copy-dir-entries-error")

			bundle.InstallFs = fs

			blobstore.GetFileName = "/dev/null"

			err := applier.Apply(job)
			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(ContainSubstring("fake-copy-dir-entries-error"))
		})
		It("configure", func() {

			jobsBc, _, _, jobSupervisor, applier := buildJobApplier()
			job, bundle := buildJob(jobsBc)

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
}
