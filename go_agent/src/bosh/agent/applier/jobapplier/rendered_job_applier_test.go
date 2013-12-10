package jobapplier

import (
	fakebc "bosh/agent/applier/bundlecollection/fakes"
	models "bosh/agent/applier/models"
	fakeblob "bosh/blobstore/fakes"
	fakedisk "bosh/platform/disk/fakes"
	fakesys "bosh/system/fakes"
	"errors"
	"github.com/stretchr/testify/assert"
	"os"
	"testing"
)

func TestApplyInstallsAndEnablesJob(t *testing.T) {
	jobsBc, _, _, applier := buildJobApplier()
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
	jobsBc, _, _, applier := buildJobApplier()
	job := buildJob()

	jobsBc.InstallError = errors.New("fake-install-error")

	err := applier.Apply(job)
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "fake-install-error")
}

func TestApplyErrsWhenJobEnableFails(t *testing.T) {
	jobsBc, _, _, applier := buildJobApplier()
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
	jobsBc, blobstore, _, applier := buildJobApplier()
	job := buildJob()
	job.Source.BlobstoreId = "fake-blobstore-id"

	file, err := os.Open("/dev/null")
	assert.NoError(t, err)
	defer file.Close()

	fs := fakesys.NewFakeFileSystem()
	jobsBc.InstallFs = fs
	jobsBc.InstallPath = "fake-install-dir"
	fs.MkdirAll("fake-install-dir", os.FileMode(0))

	blobstore.GetFile = file

	err = applier.Apply(job)
	assert.NoError(t, err)
	assert.Equal(t, "fake-blobstore-id", blobstore.GetBlobIds[0])
	assert.Equal(t, file, blobstore.CleanUpFile)
}

func TestApplyErrsWhenJobDownloadErrs(t *testing.T) {
	_, blobstore, _, applier := buildJobApplier()
	job := buildJob()

	blobstore.GetError = errors.New("fake-get-error")

	err := applier.Apply(job)
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "fake-get-error")
}

func TestApplyDecompressesJobToTmpPathAndCleansItUp(t *testing.T) {
	jobsBc, blobstore, compressor, applier := buildJobApplier()
	job := buildJob()

	file, err := os.Open("/dev/null")
	assert.NoError(t, err)
	defer file.Close()

	fs := fakesys.NewFakeFileSystem()
	fs.TempDirDir = "fake-tmp-dir"
	fs.MkdirAll("fake-tmp-dir", os.FileMode(0))

	jobsBc.InstallFs = fs
	jobsBc.InstallPath = "fake-install-dir"
	fs.MkdirAll("fake-install-dir", os.FileMode(0))

	blobstore.GetFile = file

	err = applier.Apply(job)
	assert.NoError(t, err)
	assert.Equal(t, file, compressor.DecompressFileToDirTarballs[0])
	assert.Equal(t, "fake-tmp-dir", compressor.DecompressFileToDirDirs[0])
	assert.Nil(t, fs.GetFileTestStat(fs.TempDirDir))
}

func TestApplyErrsWhenTempDirErrs(t *testing.T) {
	jobsBc, blobstore, _, applier := buildJobApplier()
	job := buildJob()

	file, err := os.Open("/dev/null")
	assert.NoError(t, err)
	defer file.Close()

	fs := fakesys.NewFakeFileSystem()
	fs.TempDirError = errors.New("fake-filesystem-tempdir-error")
	jobsBc.InstallFs = fs

	blobstore.GetFile = file

	err = applier.Apply(job)
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "fake-filesystem-tempdir-error")
}

func TestApplyErrsWhenJobDecompressErrs(t *testing.T) {
	jobsBc, _, compressor, applier := buildJobApplier()
	job := buildJob()

	compressor.DecompressFileToDirError = errors.New("fake-decompress-error")

	fs := fakesys.NewFakeFileSystem()
	jobsBc.InstallFs = fs

	err := applier.Apply(job)
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "fake-decompress-error")
}

func TestApplyCopiesFromDecompressedTmpPathToInstallPath(t *testing.T) {
	jobsBc, blobstore, compressor, applier := buildJobApplier()
	job := buildJob()
	job.Source.PathInArchive = "fake-path-in-archive"

	file, err := os.Open("/dev/null")
	assert.NoError(t, err)
	defer file.Close()

	fs := fakesys.NewFakeFileSystem()
	fs.TempDirDir = "fake-tmp-dir"
	fs.MkdirAll("fake-tmp-dir", os.FileMode(0))

	jobsBc.InstallFs = fs
	jobsBc.InstallPath = "fake-install-dir"
	fs.MkdirAll("fake-install-dir", os.FileMode(0))

	blobstore.GetFile = file

	compressor.DecompressFileToDirCallBack = func() {
		fs.MkdirAll("fake-tmp-dir/fake-path-in-archive", os.FileMode(0))
		fs.WriteToFile("fake-tmp-dir/fake-path-in-archive/file", "file-contents")
	}

	err = applier.Apply(job)
	assert.NoError(t, err)
	fileInArchiveStat := fs.GetFileTestStat("fake-install-dir/file")
	assert.NotNil(t, fileInArchiveStat)
	assert.Equal(t, "file-contents", fileInArchiveStat.Content)
}

func TestApplySetsExecutableBitForFilesInBin(t *testing.T) {
	jobsBc, blobstore, compressor, applier := buildJobApplier()
	job := buildJob()
	job.Source.PathInArchive = "fake-path-in-archive"

	file, _ := os.Open("/dev/null")
	defer file.Close()
	blobstore.GetFile = file

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
	jobsBc, blobstore, _, applier := buildJobApplier()
	job := buildJob()

	file, err := os.Open("/dev/null")
	assert.NoError(t, err)
	defer file.Close()

	fs := fakesys.NewFakeFileSystem()
	fs.TempDirDir = "fake-tmp-dir"
	fs.CopyDirEntriesError = errors.New("fake-copy-dir-entries-error")

	jobsBc.InstallFs = fs

	blobstore.GetFile = file

	err = applier.Apply(job)
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "fake-copy-dir-entries-error")
}

func buildJobApplier() (
	*fakebc.FakeBundleCollection,
	*fakeblob.FakeBlobstore,
	*fakedisk.FakeCompressor,
	JobApplier,
) {
	jobsBc := fakebc.NewFakeBundleCollection()
	blobstore := fakeblob.NewFakeBlobstore()
	compressor := fakedisk.NewFakeCompressor()
	applier := NewRenderedJobApplier(jobsBc, blobstore, compressor)
	return jobsBc, blobstore, compressor, applier
}

func buildJob() models.Job {
	return models.Job{Name: "fake-job-name", Version: "fake-job-name"}
}
