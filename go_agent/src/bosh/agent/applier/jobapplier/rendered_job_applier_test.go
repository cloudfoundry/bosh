package jobapplier_test

import (
	fakebc "bosh/agent/applier/bundlecollection/fakes"
	. "bosh/agent/applier/jobapplier"
	models "bosh/agent/applier/models"
	fakeblob "bosh/blobstore/fakes"
	fakejobsuper "bosh/jobsupervisor/fakes"
	fakecmd "bosh/platform/commands/fakes"
	fakesys "bosh/system/fakes"
	"errors"
	. "github.com/onsi/ginkgo"
	"github.com/stretchr/testify/assert"
	"os"
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
			assert.NoError(GinkgoT(), err)
			assert.True(GinkgoT(), bundle.Installed)
			assert.True(GinkgoT(), bundle.Enabled)
		})
		It("apply errs when job install fails", func() {

			jobsBc, _, _, _, applier := buildJobApplier()
			job, bundle := buildJob(jobsBc)

			bundle.InstallError = errors.New("fake-install-error")

			err := applier.Apply(job)
			assert.Error(GinkgoT(), err)
			assert.Contains(GinkgoT(), err.Error(), "fake-install-error")
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
			assert.Error(GinkgoT(), err)
			assert.Contains(GinkgoT(), err.Error(), "fake-enable-error")
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
			assert.NoError(GinkgoT(), err)
			assert.Equal(GinkgoT(), "fake-blobstore-id", blobstore.GetBlobIds[0])
			assert.Equal(GinkgoT(), "blob-sha1", blobstore.GetFingerprints[0])
			assert.Equal(GinkgoT(), blobstore.GetFileName, blobstore.CleanUpFileName)
		})
		It("apply errs when job download errs", func() {

			jobsBc, blobstore, _, _, applier := buildJobApplier()
			job, _ := buildJob(jobsBc)

			blobstore.GetError = errors.New("fake-get-error")

			err := applier.Apply(job)
			assert.Error(GinkgoT(), err)
			assert.Contains(GinkgoT(), err.Error(), "fake-get-error")
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
			assert.NoError(GinkgoT(), err)
			assert.Equal(GinkgoT(), blobstore.GetFileName, compressor.DecompressFileToDirTarballPaths[0])
			assert.Equal(GinkgoT(), "fake-tmp-dir", compressor.DecompressFileToDirDirs[0])
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
			assert.Error(GinkgoT(), err)
			assert.Contains(GinkgoT(), err.Error(), "fake-filesystem-tempdir-error")
		})
		It("apply errs when job decompress errs", func() {

			jobsBc, _, compressor, _, applier := buildJobApplier()
			job, bundle := buildJob(jobsBc)

			compressor.DecompressFileToDirError = errors.New("fake-decompress-error")

			fs := fakesys.NewFakeFileSystem()
			bundle.InstallFs = fs

			err := applier.Apply(job)
			assert.Error(GinkgoT(), err)
			assert.Contains(GinkgoT(), err.Error(), "fake-decompress-error")
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
				fs.WriteToFile("fake-tmp-dir/fake-path-in-archive/file", "file-contents")
			}

			err := applier.Apply(job)
			assert.NoError(GinkgoT(), err)
			fileInArchiveStat := fs.GetFileTestStat("fake-install-dir/file")
			assert.NotNil(GinkgoT(), fileInArchiveStat)
			assert.Equal(GinkgoT(), "file-contents", fileInArchiveStat.Content)
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
				fs.WriteToFile("fake-tmp-dir/fake-path-in-archive/bin/test1", "")
				fs.WriteToFile("fake-tmp-dir/fake-path-in-archive/bin/test2", "")
				fs.WriteToFile("fake-tmp-dir/fake-path-in-archive/config/test", "")
			}

			fs.GlobPaths = []string{"fake-install-dir/bin/test1", "fake-install-dir/bin/test2"}

			err := applier.Apply(job)
			assert.NoError(GinkgoT(), err)

			assert.Equal(GinkgoT(), "fake-install-dir/bin/*", fs.GlobPattern)

			testBin1Stats := fs.GetFileTestStat("fake-install-dir/bin/test1")
			assert.NotNil(GinkgoT(), testBin1Stats)
			assert.Equal(GinkgoT(), 0755, int(testBin1Stats.FileMode))

			testBin2Stats := fs.GetFileTestStat("fake-install-dir/bin/test2")
			assert.NotNil(GinkgoT(), testBin2Stats)
			assert.Equal(GinkgoT(), 0755, int(testBin2Stats.FileMode))

			testConfigStats := fs.GetFileTestStat("fake-install-dir/config/test")
			assert.NotNil(GinkgoT(), testConfigStats)
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
			assert.Error(GinkgoT(), err)
			assert.Contains(GinkgoT(), err.Error(), "fake-copy-dir-entries-error")
		})
		It("configure", func() {

			jobsBc, _, _, jobSupervisor, applier := buildJobApplier()
			job, bundle := buildJob(jobsBc)

			fs := fakesys.NewFakeFileSystem()
			fs.WriteToFile("/path/to/job/monit", "some conf")
			fs.GlobPaths = []string{"/path/to/job/subjob.monit"}

			bundle.GetDirPath = "/path/to/job"
			bundle.GetDirFs = fs

			err := applier.Configure(job, 0)
			assert.NoError(GinkgoT(), err)

			assert.Equal(GinkgoT(), "/path/to/job/*.monit", fs.GlobPattern)
			assert.Equal(GinkgoT(), 2, len(jobSupervisor.AddJobArgs))

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
			assert.Equal(GinkgoT(), firstArgs, jobSupervisor.AddJobArgs[0])
			assert.Equal(GinkgoT(), secondArgs, jobSupervisor.AddJobArgs[1])
		})
	})
}
