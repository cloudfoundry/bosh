package applyspec

import (
	fakebc "bosh/agent/applyspec/bundlecollection/fakes"
	fakeblob "bosh/blobstore/fakes"
	fakedisk "bosh/platform/disk/fakes"
	"errors"
	"github.com/stretchr/testify/assert"
	"os"
	"testing"
)

func TestApplyInstallsAndEnablesJobs(t *testing.T) {
	jobsBc, _, _, _, applier := buildApplier()
	job := buildJob()

	err := applier.Apply([]Job{job}, []Package{})
	assert.NoError(t, err)
	assert.True(t, jobsBc.IsInstalled(job))
	assert.True(t, jobsBc.IsEnabled(job))
}

func TestApplyErrsWhenJobInstallFails(t *testing.T) {
	jobsBc, _, _, _, applier := buildApplier()
	job := buildJob()

	jobsBc.InstallError = errors.New("fake-install-error")

	err := applier.Apply([]Job{job}, []Package{})
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "fake-install-error")
}

func TestApplyErrsWhenJobEnableFails(t *testing.T) {
	jobsBc, _, _, _, applier := buildApplier()
	job := buildJob()

	jobsBc.EnableError = errors.New("fake-enable-error")

	err := applier.Apply([]Job{job}, []Package{})
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "fake-enable-error")
}

func TestApplyInstallsAndEnablesPackages(t *testing.T) {
	_, packagesBc, _, _, applier := buildApplier()
	pkg := buildPackage()

	err := applier.Apply([]Job{}, []Package{pkg})
	assert.NoError(t, err)
	assert.True(t, packagesBc.IsInstalled(pkg))
	assert.True(t, packagesBc.IsEnabled(pkg))
}

func TestApplyErrsWhenPackageInstallFails(t *testing.T) {
	_, packagesBc, _, _, applier := buildApplier()
	pkg := buildPackage()

	packagesBc.InstallError = errors.New("fake-install-error")

	err := applier.Apply([]Job{}, []Package{pkg})
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "fake-install-error")
}

func TestApplyErrsWhenPackageEnableFails(t *testing.T) {
	_, packagesBc, _, _, applier := buildApplier()
	pkg := buildPackage()

	packagesBc.EnableError = errors.New("fake-enable-error")

	err := applier.Apply([]Job{}, []Package{pkg})
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "fake-enable-error")
}

func TestApplyDownloadsAndCleansUpPackage(t *testing.T) {
	_, _, blobstore, _, applier := buildApplier()
	pkg := buildPackage()
	pkg.BlobstoreId = "fake-blobstore-id"

	file, err := os.Open("/dev/null")
	assert.NoError(t, err)
	defer file.Close()

	blobstore.GetFile = file

	err = applier.Apply([]Job{}, []Package{pkg})
	assert.NoError(t, err)
	assert.Equal(t, "fake-blobstore-id", blobstore.GetBlobId)
	assert.Equal(t, file, blobstore.CleanUpFile)
}

func TestApplyErrsWhenPackageDownloadErrs(t *testing.T) {
	_, _, blobstore, _, applier := buildApplier()
	pkg := buildPackage()

	blobstore.GetError = errors.New("fake-get-error")

	err := applier.Apply([]Job{}, []Package{pkg})
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "fake-get-error")
}

func TestApplyDecompressesPackageToInstallPath(t *testing.T) {
	_, packagesBc, blobstore, compressor, applier := buildApplier()
	pkg := buildPackage()

	file, err := os.Open("/dev/null")
	assert.NoError(t, err)
	defer file.Close()

	packagesBc.InstallPath = "fake-install-path"
	blobstore.GetFile = file

	err = applier.Apply([]Job{}, []Package{pkg})
	assert.NoError(t, err)
	assert.Equal(t, file, compressor.DecompressFileToDirTarball)
	assert.Equal(t, "fake-install-path", compressor.DecompressFileToDirDir)
}

func TestApplyErrsWhenPackageDecompressErrs(t *testing.T) {
	_, _, _, compressor, applier := buildApplier()
	pkg := buildPackage()

	compressor.DecompressFileToDirError = errors.New("fake-decompress-error")

	err := applier.Apply([]Job{}, []Package{pkg})
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "fake-decompress-error")
}

func buildApplier() (
	*fakebc.FakeBundleCollection,
	*fakebc.FakeBundleCollection,
	*fakeblob.FakeBlobstore,
	*fakedisk.FakeCompressor,
	Applier,
) {
	jobsBc := fakebc.NewFakeBundleCollection()
	packagesBc := fakebc.NewFakeBundleCollection()
	blobstore := fakeblob.NewFakeBlobstore()
	compressor := fakedisk.NewFakeCompressor()
	applier := NewConcreteApplier(jobsBc, packagesBc, blobstore, compressor)
	return jobsBc, packagesBc, blobstore, compressor, applier
}

func buildJob() Job {
	return Job{Name: "fake-job-name", Version: "fake-version-name"}
}

func buildPackage() Package {
	return Package{Name: "fake-package-name", Version: "fake-package-name"}
}
