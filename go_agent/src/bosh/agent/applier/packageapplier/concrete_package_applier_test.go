package packageapplier_test

import (
	fakebc "bosh/agent/applier/bundlecollection/fakes"
	models "bosh/agent/applier/models"
	. "bosh/agent/applier/packageapplier"
	fakeblob "bosh/blobstore/fakes"
	fakecmd "bosh/platform/commands/fakes"
	"errors"
	. "github.com/onsi/ginkgo"
	"github.com/stretchr/testify/assert"
)

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

func buildPackage(pkgBc *fakebc.FakeBundleCollection) (pkg models.Package, bundle *fakebc.FakeBundle) {
	pkg = models.Package{Name: "fake-package-name", Version: "fake-package-name"}
	bundle = pkgBc.FakeGet(pkg)
	return
}
func init() {
	Describe("Testing with Ginkgo", func() {
		It("apply installs and enables package", func() {
			packagesBc, _, _, applier := buildPackageApplier()
			pkg, bundle := buildPackage(packagesBc)

			err := applier.Apply(pkg)
			assert.NoError(GinkgoT(), err)
			assert.True(GinkgoT(), bundle.Installed)
			assert.True(GinkgoT(), bundle.Enabled)
		})
		It("apply errs when package install fails", func() {

			packagesBc, _, _, applier := buildPackageApplier()
			pkg, bundle := buildPackage(packagesBc)

			bundle.InstallError = errors.New("fake-install-error")

			err := applier.Apply(pkg)
			assert.Error(GinkgoT(), err)
			assert.Contains(GinkgoT(), err.Error(), "fake-install-error")
		})
		It("apply errs when package enable fails", func() {

			packagesBc, _, _, applier := buildPackageApplier()
			pkg, bundle := buildPackage(packagesBc)

			bundle.EnableError = errors.New("fake-enable-error")

			err := applier.Apply(pkg)
			assert.Error(GinkgoT(), err)
			assert.Contains(GinkgoT(), err.Error(), "fake-enable-error")
		})
		It("apply downloads and cleans up package", func() {

			packagesBc, blobstore, _, applier := buildPackageApplier()
			pkg, _ := buildPackage(packagesBc)
			pkg.Source.BlobstoreId = "fake-blobstore-id"
			pkg.Source.Sha1 = "blob-sha1"

			blobstore.GetFileName = "/dev/null"

			err := applier.Apply(pkg)
			assert.NoError(GinkgoT(), err)
			assert.Equal(GinkgoT(), "fake-blobstore-id", blobstore.GetBlobIds[0])
			assert.Equal(GinkgoT(), "blob-sha1", blobstore.GetFingerprints[0])
			assert.Equal(GinkgoT(), blobstore.GetFileName, blobstore.CleanUpFileName)
		})
		It("apply errs when package download errs", func() {

			packagesBc, blobstore, _, applier := buildPackageApplier()
			pkg, _ := buildPackage(packagesBc)

			blobstore.GetError = errors.New("fake-get-error")

			err := applier.Apply(pkg)
			assert.Error(GinkgoT(), err)
			assert.Contains(GinkgoT(), err.Error(), "fake-get-error")
		})
		It("apply decompresses package to install path", func() {

			packagesBc, blobstore, compressor, applier := buildPackageApplier()
			pkg, bundle := buildPackage(packagesBc)

			bundle.InstallPath = "fake-install-path"
			blobstore.GetFileName = "/dev/null"

			err := applier.Apply(pkg)
			assert.NoError(GinkgoT(), err)
			assert.Equal(GinkgoT(), blobstore.GetFileName, compressor.DecompressFileToDirTarballPaths[0])
			assert.Equal(GinkgoT(), "fake-install-path", compressor.DecompressFileToDirDirs[0])
		})
		It("apply errs when package decompress errs", func() {

			packagesBc, _, compressor, applier := buildPackageApplier()
			pkg, _ := buildPackage(packagesBc)

			compressor.DecompressFileToDirError = errors.New("fake-decompress-error")

			err := applier.Apply(pkg)
			assert.Error(GinkgoT(), err)
			assert.Contains(GinkgoT(), err.Error(), "fake-decompress-error")
		})
	})
}
