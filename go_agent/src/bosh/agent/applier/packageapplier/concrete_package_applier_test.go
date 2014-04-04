package packageapplier_test

import (
	"errors"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	fakebc "bosh/agent/applier/bundlecollection/fakes"
	models "bosh/agent/applier/models"
	. "bosh/agent/applier/packageapplier"
	fakeblob "bosh/blobstore/fakes"
	fakecmd "bosh/platform/commands/fakes"
	boshuuid "bosh/uuid"
)

func buildPackage(bc *fakebc.FakeBundleCollection) (models.Package, *fakebc.FakeBundle) {
	uuidGen := boshuuid.NewGenerator()
	uuid, err := uuidGen.Generate()
	Expect(err).ToNot(HaveOccurred())

	pkg := models.Package{
		Name:    "fake-package-name" + uuid,
		Version: "fake-package-name",
	}

	bundle := bc.FakeGet(pkg)

	return pkg, bundle
}

func init() {
	Describe("concretePackageApplier", func() {
		var (
			packagesBc *fakebc.FakeBundleCollection
			blobstore  *fakeblob.FakeBlobstore
			compressor *fakecmd.FakeCompressor
			applier    PackageApplier
		)

		BeforeEach(func() {
			packagesBc = fakebc.NewFakeBundleCollection()
			blobstore = fakeblob.NewFakeBlobstore()
			compressor = fakecmd.NewFakeCompressor()
			applier = NewConcretePackageApplier(packagesBc, blobstore, compressor)
		})
		Describe("Apply", func() {
			var (
				pkg    models.Package
				bundle *fakebc.FakeBundle
			)

			BeforeEach(func() {
				pkg, bundle = buildPackage(packagesBc)
			})

			It("installs and enables package", func() {
				err := applier.Apply(pkg)
				Expect(err).ToNot(HaveOccurred())
				Expect(bundle.Installed).To(BeTrue())
				Expect(bundle.Enabled).To(BeTrue())
			})

			It("returns error when package install fails", func() {
				bundle.InstallError = errors.New("fake-install-error")

				err := applier.Apply(pkg)
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("fake-install-error"))
			})

			It("returns error when package enable fails", func() {
				bundle.EnableError = errors.New("fake-enable-error")

				err := applier.Apply(pkg)
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("fake-enable-error"))
			})

			It("downloads and cleans up package", func() {
				pkg.Source.BlobstoreId = "fake-blobstore-id"
				pkg.Source.Sha1 = "blob-sha1"

				blobstore.GetFileName = "/dev/null"

				err := applier.Apply(pkg)
				Expect(err).ToNot(HaveOccurred())
				Expect("fake-blobstore-id").To(Equal(blobstore.GetBlobIds[0]))
				Expect("blob-sha1").To(Equal(blobstore.GetFingerprints[0]))
				Expect(blobstore.GetFileName).To(Equal(blobstore.CleanUpFileName))
			})

			It("returns error when package download errs", func() {
				blobstore.GetError = errors.New("fake-get-error")

				err := applier.Apply(pkg)
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("fake-get-error"))
			})

			It("decompresses package to install path", func() {
				bundle.InstallPath = "fake-install-path"
				blobstore.GetFileName = "/dev/null"

				err := applier.Apply(pkg)
				Expect(err).ToNot(HaveOccurred())
				Expect(blobstore.GetFileName).To(Equal(compressor.DecompressFileToDirTarballPaths[0]))
				Expect("fake-install-path").To(Equal(compressor.DecompressFileToDirDirs[0]))
			})

			It("return error when package decompress errs", func() {
				compressor.DecompressFileToDirError = errors.New("fake-decompress-error")

				err := applier.Apply(pkg)
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("fake-decompress-error"))
			})
		})
	})
}
