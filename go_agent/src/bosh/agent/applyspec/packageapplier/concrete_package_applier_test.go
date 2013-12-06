package packageapplier

import (
	fakebc "bosh/agent/applyspec/bundlecollection/fakes"
	models "bosh/agent/applyspec/models"
	fakeblob "bosh/blobstore/fakes"
	fakedisk "bosh/platform/disk/fakes"
	"errors"
	"github.com/stretchr/testify/assert"
	"os"
	"testing"
)

func TestApplyInstallsAndEnablesPackage(t *testing.T) {
	packagesBc, _, _, applier := buildPackageApplier()
	pkg := buildPackage()

	err := applier.Apply(pkg)
	assert.NoError(t, err)
	assert.True(t, packagesBc.IsInstalled(pkg))
	assert.True(t, packagesBc.IsEnabled(pkg))
}

func TestApplyErrsWhenPackageInstallFails(t *testing.T) {
	packagesBc, _, _, applier := buildPackageApplier()
	pkg := buildPackage()

	packagesBc.InstallError = errors.New("fake-install-error")

	err := applier.Apply(pkg)
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "fake-install-error")
}

func TestApplyErrsWhenPackageEnableFails(t *testing.T) {
	packagesBc, _, _, applier := buildPackageApplier()
	pkg := buildPackage()

	packagesBc.EnableError = errors.New("fake-enable-error")

	err := applier.Apply(pkg)
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "fake-enable-error")
}

func TestApplyDownloadsAndCleansUpPackage(t *testing.T) {
	_, blobstore, _, applier := buildPackageApplier()
	pkg := buildPackage()
	pkg.BlobstoreId = "fake-blobstore-id"

	file, err := os.Open("/dev/null")
	assert.NoError(t, err)
	defer file.Close()

	blobstore.GetFile = file

	err = applier.Apply(pkg)
	assert.NoError(t, err)
	assert.Equal(t, "fake-blobstore-id", blobstore.GetBlobId)
	assert.Equal(t, file, blobstore.CleanUpFile)
}

func TestApplyErrsWhenPackageDownloadErrs(t *testing.T) {
	_, blobstore, _, applier := buildPackageApplier()
	pkg := buildPackage()

	blobstore.GetError = errors.New("fake-get-error")

	err := applier.Apply(pkg)
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "fake-get-error")
}

func TestApplyDecompressesPackageToInstallPath(t *testing.T) {
	packagesBc, blobstore, compressor, applier := buildPackageApplier()
	pkg := buildPackage()

	file, err := os.Open("/dev/null")
	assert.NoError(t, err)
	defer file.Close()

	packagesBc.InstallPath = "fake-install-path"
	blobstore.GetFile = file

	err = applier.Apply(pkg)
	assert.NoError(t, err)
	assert.Equal(t, file, compressor.DecompressFileToDirTarball)
	assert.Equal(t, "fake-install-path", compressor.DecompressFileToDirDir)
}

func TestApplyErrsWhenPackageDecompressErrs(t *testing.T) {
	_, _, compressor, applier := buildPackageApplier()
	pkg := buildPackage()

	compressor.DecompressFileToDirError = errors.New("fake-decompress-error")

	err := applier.Apply(pkg)
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "fake-decompress-error")
}

func buildPackageApplier() (
	*fakebc.FakeBundleCollection,
	*fakeblob.FakeBlobstore,
	*fakedisk.FakeCompressor,
	PackageApplier,
) {
	packagesBc := fakebc.NewFakeBundleCollection()
	blobstore := fakeblob.NewFakeBlobstore()
	compressor := fakedisk.NewFakeCompressor()
	applier := NewConcretePackageApplier(packagesBc, blobstore, compressor)
	return packagesBc, blobstore, compressor, applier
}

func buildPackage() models.Package {
	return models.Package{Name: "fake-package-name", Version: "fake-package-name"}
}
