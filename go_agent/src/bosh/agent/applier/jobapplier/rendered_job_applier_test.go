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
	pkg := buildJob()

	fs := fakesys.NewFakeFileSystem()
	jobsBc.InstallFs = fs
	jobsBc.InstallPath = "fake-install-dir"
	fs.MkdirAll("fake-install-dir", os.FileMode(0))

	err := applier.Apply(pkg)
	assert.NoError(t, err)
	assert.True(t, jobsBc.IsInstalled(pkg))
	assert.True(t, jobsBc.IsEnabled(pkg))
}

func TestApplyErrsWhenJobInstallFails(t *testing.T) {
	jobsBc, _, _, applier := buildJobApplier()
	pkg := buildJob()

	jobsBc.InstallError = errors.New("fake-install-error")

	err := applier.Apply(pkg)
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "fake-install-error")
}

func TestApplyErrsWhenJobEnableFails(t *testing.T) {
	jobsBc, _, _, applier := buildJobApplier()
	pkg := buildJob()

	fs := fakesys.NewFakeFileSystem()
	jobsBc.InstallFs = fs
	jobsBc.InstallPath = "fake-install-dir"
	fs.MkdirAll("fake-install-dir", os.FileMode(0))

	jobsBc.EnableError = errors.New("fake-enable-error")

	err := applier.Apply(pkg)
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "fake-enable-error")
}

func TestApplyDownloadsAndCleansUpJob(t *testing.T) {
	jobsBc, blobstore, _, applier := buildJobApplier()
	pkg := buildJob()
	pkg.Source.BlobstoreId = "fake-blobstore-id"

	file, err := os.Open("/dev/null")
	assert.NoError(t, err)
	defer file.Close()

	fs := fakesys.NewFakeFileSystem()
	jobsBc.InstallFs = fs
	jobsBc.InstallPath = "fake-install-dir"
	fs.MkdirAll("fake-install-dir", os.FileMode(0))

	blobstore.GetFile = file

	err = applier.Apply(pkg)
	assert.NoError(t, err)
	assert.Equal(t, "fake-blobstore-id", blobstore.GetBlobId)
	assert.Equal(t, file, blobstore.CleanUpFile)
}

func TestApplyErrsWhenJobDownloadErrs(t *testing.T) {
	_, blobstore, _, applier := buildJobApplier()
	pkg := buildJob()

	blobstore.GetError = errors.New("fake-get-error")

	err := applier.Apply(pkg)
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "fake-get-error")
}

func TestApplyDecompressesJobToTmpPath(t *testing.T) {
	jobsBc, blobstore, compressor, applier := buildJobApplier()
	pkg := buildJob()

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

	err = applier.Apply(pkg)
	assert.NoError(t, err)
	assert.Equal(t, file, compressor.DecompressFileToDirTarball)
	assert.Equal(t, "fake-tmp-dir", compressor.DecompressFileToDirDir)
}

func TestApplyErrsWhenTempDirErrs(t *testing.T) {
	jobsBc, blobstore, _, applier := buildJobApplier()
	pkg := buildJob()

	file, err := os.Open("/dev/null")
	assert.NoError(t, err)
	defer file.Close()

	fs := fakesys.NewFakeFileSystem()
	fs.TempDirError = errors.New("fake-filesystem-tempdir-error")
	jobsBc.InstallFs = fs

	blobstore.GetFile = file

	err = applier.Apply(pkg)
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "fake-filesystem-tempdir-error")
}

func TestApplyErrsWhenJobDecompressErrs(t *testing.T) {
	jobsBc, _, compressor, applier := buildJobApplier()
	pkg := buildJob()

	compressor.DecompressFileToDirError = errors.New("fake-decompress-error")

	fs := fakesys.NewFakeFileSystem()
	jobsBc.InstallFs = fs

	err := applier.Apply(pkg)
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "fake-decompress-error")
}

func TestApplyCopiesFromDecompressedTmpPathToInstallPath(t *testing.T) {
	jobsBc, blobstore, _, applier := buildJobApplier()
	pkg := buildJob()

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

	err = applier.Apply(pkg)
	assert.NoError(t, err)
	assert.Equal(t, "fake-tmp-dir", fs.CopyDirEntriesSrcPath)
	assert.Equal(t, "fake-install-dir", fs.CopyDirEntriesDstPath)
}

func TestApplyErrsWhenCopyAllErrs(t *testing.T) {
	jobsBc, blobstore, _, applier := buildJobApplier()
	pkg := buildJob()

	file, err := os.Open("/dev/null")
	assert.NoError(t, err)
	defer file.Close()

	fs := fakesys.NewFakeFileSystem()
	fs.TempDirDir = "fake-tmp-dir"
	fs.CopyDirEntriesError = errors.New("fake-copy-dir-entries-error")

	jobsBc.InstallFs = fs

	blobstore.GetFile = file

	err = applier.Apply(pkg)
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
