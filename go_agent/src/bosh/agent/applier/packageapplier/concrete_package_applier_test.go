package packageapplier

import (
	fakebc "bosh/agent/applier/bundlecollection/fakes"
	models "bosh/agent/applier/models"
	fakeblob "bosh/blobstore/fakes"
	fakecmd "bosh/platform/commands/fakes"
	"errors"
	"github.com/stretchr/testify/assert"
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
	pkg.Source.BlobstoreId = "fake-blobstore-id"
	pkg.Source.Sha1 = "blob-sha1"

	blobstore.GetFileName = "/dev/null"

	err := applier.Apply(pkg)
	assert.NoError(t, err)
	assert.Equal(t, "fake-blobstore-id", blobstore.GetBlobIds[0])
	assert.Equal(t, "blob-sha1", blobstore.GetFingerprints[0])
	assert.Equal(t, blobstore.GetFileName, blobstore.CleanUpFileName)
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

	packagesBc.InstallPath = "fake-install-path"
	blobstore.GetFileName = "/dev/null"

	err := applier.Apply(pkg)
	assert.NoError(t, err)
	assert.Equal(t, blobstore.GetFileName, compressor.DecompressFileToDirTarballPaths[0])
	assert.Equal(t, "fake-install-path", compressor.DecompressFileToDirDirs[0])
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
	*fakecmd.FakeCompressor,
	PackageApplier,
) {
	packagesBc := fakebc.NewFakeBundleCollection()
	blobstore := fakeblob.NewFakeBlobstore()
	compressor := fakecmd.NewFakeCompressor()
	applier := NewConcretePackageApplier(packagesBc, blobstore, compressor)
	return packagesBc, blobstore, compressor, applier
}

func buildPackage() models.Package {
	return models.Package{Name: "fake-package-name", Version: "fake-package-name"}
}
