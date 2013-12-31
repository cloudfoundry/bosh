package jobapplier

import (
	fakebc "bosh/agent/applier/bundlecollection/fakes"
	models "bosh/agent/applier/models"
	fakeblob "bosh/blobstore/fakes"
	fakejobsuper "bosh/jobsupervisor/fakes"
	fakecmd "bosh/platform/commands/fakes"
	fakesys "bosh/system/fakes"
	"errors"
	"github.com/stretchr/testify/assert"
	"os"
	"testing"
)

func TestApplyInstallsAndEnablesJob(t *testing.T) {
	jobsBc, _, _, _, applier := buildJobApplier()
	job := buildJob()

	fs := fakesys.NewFakeFileSystem()
	jobsBc.InstallFs = fs
	jobsBc.InstallPath = "fake-install-dir"
	fs.MkdirAll("fake-install-dir", os.FileMode(0))

	err := applier.Apply(job)
	assert.NoError(t, err)
	assert.True(t, jobsBc.IsInstalled(job))
	assert.True(t, jobsBc.IsEnabled(job))
}

func TestApplyErrsWhenJobInstallFails(t *testing.T) {
	jobsBc, _, _, _, applier := buildJobApplier()
	job := buildJob()

	jobsBc.InstallError = errors.New("fake-install-error")

	err := applier.Apply(job)
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "fake-install-error")
}

func TestApplyErrsWhenJobEnableFails(t *testing.T) {
	jobsBc, _, _, _, applier := buildJobApplier()
	job := buildJob()

	fs := fakesys.NewFakeFileSystem()
	jobsBc.InstallFs = fs
	jobsBc.InstallPath = "fake-install-dir"
	fs.MkdirAll("fake-install-dir", os.FileMode(0))

	jobsBc.EnableError = errors.New("fake-enable-error")

	err := applier.Apply(job)
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "fake-enable-error")
}

func TestApplyDownloadsAndCleansUpJob(t *testing.T) {
	jobsBc, blobstore, _, _, applier := buildJobApplier()
	job := buildJob()
	job.Source.BlobstoreId = "fake-blobstore-id"
	job.Source.Sha1 = "blob-sha1"

	fs := fakesys.NewFakeFileSystem()
	jobsBc.InstallFs = fs
	jobsBc.InstallPath = "fake-install-dir"
	fs.MkdirAll("fake-install-dir", os.FileMode(0))

	blobstore.GetFileName = "/dev/null"

	err := applier.Apply(job)
	assert.NoError(t, err)
	assert.Equal(t, "fake-blobstore-id", blobstore.GetBlobIds[0])
	assert.Equal(t, "blob-sha1", blobstore.GetFingerprints[0])
	assert.Equal(t, blobstore.GetFileName, blobstore.CleanUpFileName)
}

func TestApplyErrsWhenJobDownloadErrs(t *testing.T) {
	_, blobstore, _, _, applier := buildJobApplier()
	job := buildJob()

	blobstore.GetError = errors.New("fake-get-error")

	err := applier.Apply(job)
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "fake-get-error")
}

func TestApplyDecompressesJobToTmpPathAndCleansItUp(t *testing.T) {
	jobsBc, blobstore, compressor, _, applier := buildJobApplier()
	job := buildJob()

	fs := fakesys.NewFakeFileSystem()
	fs.TempDirDir = "fake-tmp-dir"
	fs.MkdirAll("fake-tmp-dir", os.FileMode(0))

	jobsBc.InstallFs = fs
	jobsBc.InstallPath = "fake-install-dir"
	fs.MkdirAll("fake-install-dir", os.FileMode(0))

	blobstore.GetFileName = "/dev/null"

	err := applier.Apply(job)
	assert.NoError(t, err)
	assert.Equal(t, blobstore.GetFileName, compressor.DecompressFileToDirTarballPaths[0])
	assert.Equal(t, "fake-tmp-dir", compressor.DecompressFileToDirDirs[0])
	assert.Nil(t, fs.GetFileTestStat(fs.TempDirDir))
}

func TestApplyErrsWhenTempDirErrs(t *testing.T) {
	jobsBc, blobstore, _, _, applier := buildJobApplier()
	job := buildJob()

	fs := fakesys.NewFakeFileSystem()
	fs.TempDirError = errors.New("fake-filesystem-tempdir-error")
	jobsBc.InstallFs = fs

	blobstore.GetFileName = "/dev/null"

	err := applier.Apply(job)
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "fake-filesystem-tempdir-error")
}

func TestApplyErrsWhenJobDecompressErrs(t *testing.T) {
	jobsBc, _, compressor, _, applier := buildJobApplier()
	job := buildJob()

	compressor.DecompressFileToDirError = errors.New("fake-decompress-error")

	fs := fakesys.NewFakeFileSystem()
	jobsBc.InstallFs = fs

	err := applier.Apply(job)
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "fake-decompress-error")
}

func TestApplyCopiesFromDecompressedTmpPathToInstallPath(t *testing.T) {
	jobsBc, blobstore, compressor, _, applier := buildJobApplier()
	job := buildJob()
	job.Source.PathInArchive = "fake-path-in-archive"

	fs := fakesys.NewFakeFileSystem()
	fs.TempDirDir = "fake-tmp-dir"
	fs.MkdirAll("fake-tmp-dir", os.FileMode(0))

	jobsBc.InstallFs = fs
	jobsBc.InstallPath = "fake-install-dir"
	fs.MkdirAll("fake-install-dir", os.FileMode(0))

	blobstore.GetFileName = "/dev/null"

	compressor.DecompressFileToDirCallBack = func() {
		fs.MkdirAll("fake-tmp-dir/fake-path-in-archive", os.FileMode(0))
		fs.WriteToFile("fake-tmp-dir/fake-path-in-archive/file", "file-contents")
	}

	err := applier.Apply(job)
	assert.NoError(t, err)
	fileInArchiveStat := fs.GetFileTestStat("fake-install-dir/file")
	assert.NotNil(t, fileInArchiveStat)
	assert.Equal(t, "file-contents", fileInArchiveStat.Content)
}

func TestApplySetsExecutableBitForFilesInBin(t *testing.T) {
	jobsBc, blobstore, compressor, _, applier := buildJobApplier()
	job := buildJob()
	job.Source.PathInArchive = "fake-path-in-archive"

	blobstore.GetFileName = "/dev/null"

	fs := fakesys.NewFakeFileSystem()
	fs.TempDirDir = "fake-tmp-dir"

	jobsBc.InstallFs = fs
	jobsBc.InstallPath = "fake-install-dir"

	compressor.DecompressFileToDirCallBack = func() {
		fs.WriteToFile("fake-tmp-dir/fake-path-in-archive/bin/test1", "")
		fs.WriteToFile("fake-tmp-dir/fake-path-in-archive/bin/test2", "")
		fs.WriteToFile("fake-tmp-dir/fake-path-in-archive/config/test", "")
	}

	fs.GlobPaths = []string{"fake-install-dir/bin/test1", "fake-install-dir/bin/test2"}

	err := applier.Apply(job)
	assert.NoError(t, err)

	assert.Equal(t, "fake-install-dir/bin/*", fs.GlobPattern)

	testBin1Stats := fs.GetFileTestStat("fake-install-dir/bin/test1")
	assert.NotNil(t, testBin1Stats)
	assert.Equal(t, 0755, int(testBin1Stats.FileMode))

	testBin2Stats := fs.GetFileTestStat("fake-install-dir/bin/test2")
	assert.NotNil(t, testBin2Stats)
	assert.Equal(t, 0755, int(testBin2Stats.FileMode))

	testConfigStats := fs.GetFileTestStat("fake-install-dir/config/test")
	assert.NotNil(t, testConfigStats)
	assert.NotEqual(t, 0755, int(testConfigStats.FileMode))
}

func TestApplyErrsWhenCopyAllErrs(t *testing.T) {
	jobsBc, blobstore, _, _, applier := buildJobApplier()
	job := buildJob()

	fs := fakesys.NewFakeFileSystem()
	fs.TempDirDir = "fake-tmp-dir"
	fs.CopyDirEntriesError = errors.New("fake-copy-dir-entries-error")

	jobsBc.InstallFs = fs

	blobstore.GetFileName = "/dev/null"

	err := applier.Apply(job)
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "fake-copy-dir-entries-error")
}

func TestConfigure(t *testing.T) {
	jobsBc, _, _, jobSupervisor, applier := buildJobApplier()
	job := buildJob()

	fs := fakesys.NewFakeFileSystem()
	fs.WriteToFile("/path/to/job/monit", "some conf")
	fs.GlobPaths = []string{"/path/to/job/subjob.monit"}

	jobsBc.GetDirPath = "/path/to/job"
	jobsBc.GetDirFs = fs

	err := applier.Configure(job, 0)
	assert.NoError(t, err)

	assert.Equal(t, "/path/to/job/*.monit", fs.GlobPattern)
	assert.Equal(t, 2, len(jobSupervisor.AddJobArgs))

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
	assert.Equal(t, firstArgs, jobSupervisor.AddJobArgs[0])
	assert.Equal(t, secondArgs, jobSupervisor.AddJobArgs[1])
}

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

func buildJob() models.Job {
	return models.Job{Name: "fake-job-name", Version: "fake-job-name"}
}
