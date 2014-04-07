package packageapplier_test

import (
	"errors"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	boshbc "bosh/agent/applier/bundlecollection"
	fakebc "bosh/agent/applier/bundlecollection/fakes"
	models "bosh/agent/applier/models"
	. "bosh/agent/applier/packageapplier"
	fakeblob "bosh/blobstore/fakes"
	boshlog "bosh/logger"
	fakecmd "bosh/platform/commands/fakes"
	boshuuid "bosh/uuid"
)

func buildPkg(bc *fakebc.FakeBundleCollection) (models.Package, *fakebc.FakeBundle) {
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
			logger := boshlog.NewLogger(boshlog.LevelNone)
			applier = NewConcretePackageApplier(packagesBc, blobstore, compressor, logger)
		})
		Describe("Apply", func() {
			var (
				pkg    models.Package
				bundle *fakebc.FakeBundle
			)

			BeforeEach(func() {
				pkg, bundle = buildPkg(packagesBc)
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
				pkg.Source.BlobstoreID = "fake-blobstore-id"
				pkg.Source.Sha1 = "blob-sha1"

				blobstore.GetFileName = "/dev/null"

				err := applier.Apply(pkg)
				Expect(err).ToNot(HaveOccurred())
				Expect("fake-blobstore-id").To(Equal(blobstore.GetBlobIDs[0]))
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

		Describe("KeepOnly", func() {
			It("first disables and then uninstalls packages that are not in keeponly list", func() {
				_, bundle1 := buildPkg(packagesBc)
				pkg2, bundle2 := buildPkg(packagesBc)
				_, bundle3 := buildPkg(packagesBc)
				pkg4, bundle4 := buildPkg(packagesBc)

				packagesBc.ListBundles = []boshbc.Bundle{bundle1, bundle2, bundle3, bundle4}

				err := applier.KeepOnly([]models.Package{pkg4, pkg2})
				Expect(err).ToNot(HaveOccurred())

				Expect(bundle1.ActionsCalled).To(Equal([]string{"Disable", "Uninstall"}))
				Expect(bundle2.ActionsCalled).To(Equal([]string{}))
				Expect(bundle3.ActionsCalled).To(Equal([]string{"Disable", "Uninstall"}))
				Expect(bundle4.ActionsCalled).To(Equal([]string{}))
			})

			It("returns error when bundle collection fails to return list of installed bundles", func() {
				packagesBc.ListErr = errors.New("fake-bc-list-error")

				err := applier.KeepOnly([]models.Package{})
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("fake-bc-list-error"))
			})

			It("returns error when bundle collection cannot retrieve bundle for keep-only package", func() {
				pkg1, bundle1 := buildPkg(packagesBc)

				packagesBc.ListBundles = []boshbc.Bundle{bundle1}
				packagesBc.GetErr = errors.New("fake-bc-get-error")

				err := applier.KeepOnly([]models.Package{pkg1})
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("fake-bc-get-error"))
			})

			It("returns error when at least one bundle cannot be disabled", func() {
				_, bundle1 := buildPkg(packagesBc)

				packagesBc.ListBundles = []boshbc.Bundle{bundle1}
				bundle1.DisableErr = errors.New("fake-bc-disable-error")

				err := applier.KeepOnly([]models.Package{})
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("fake-bc-disable-error"))
			})

			It("returns error when at least one bundle cannot be uninstalled", func() {
				_, bundle1 := buildPkg(packagesBc)

				packagesBc.ListBundles = []boshbc.Bundle{bundle1}
				bundle1.UninstallErr = errors.New("fake-bc-uninstall-error")

				err := applier.KeepOnly([]models.Package{})
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("fake-bc-uninstall-error"))
			})
		})
	})
}
