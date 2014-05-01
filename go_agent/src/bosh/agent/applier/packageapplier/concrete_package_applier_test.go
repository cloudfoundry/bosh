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
	fakesys "bosh/system/fakes"
	boshuuid "bosh/uuid"
)

func buildPkg(bc *fakebc.FakeBundleCollection) (models.Package, *fakebc.FakeBundle) {
	uuidGen := boshuuid.NewGenerator()
	uuid, err := uuidGen.Generate()
	Expect(err).ToNot(HaveOccurred())

	pkg := models.Package{
		Name:    "fake-package-name" + uuid,
		Version: "fake-package-name",
		Source: models.Source{
			Sha1:        "fake-blob-sha1",
			BlobstoreID: "fake-blobstore-id",
		},
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
			fs         *fakesys.FakeFileSystem
			logger     boshlog.Logger
			applier    PackageApplier
		)

		BeforeEach(func() {
			packagesBc = fakebc.NewFakeBundleCollection()
			blobstore = fakeblob.NewFakeBlobstore()
			compressor = fakecmd.NewFakeCompressor()
			fs = fakesys.NewFakeFileSystem()
			logger = boshlog.NewLogger(boshlog.LevelNone)
			applier = NewConcretePackageApplier(packagesBc, true, blobstore, compressor, fs, logger)
		})

		Describe("Prepare & Apply", func() {
			var (
				pkg    models.Package
				bundle *fakebc.FakeBundle
			)

			BeforeEach(func() {
				pkg, bundle = buildPkg(packagesBc)
			})

			ItInstallsPkg := func(act func() error) {
				It("returns error when installing package fails", func() {
					bundle.InstallError = errors.New("fake-install-error")

					err := act()
					Expect(err).To(HaveOccurred())
					Expect(err.Error()).To(ContainSubstring("fake-install-error"))
				})

				It("downloads and later cleans up downloaded package blob", func() {
					blobstore.GetFileName = "/fake-blobstore-file-name"

					err := act()
					Expect(err).ToNot(HaveOccurred())
					Expect(blobstore.GetBlobIDs[0]).To(Equal("fake-blobstore-id"))
					Expect(blobstore.GetFingerprints[0]).To(Equal("fake-blob-sha1"))

					// downloaded file is cleaned up
					Expect(blobstore.CleanUpFileName).To(Equal("/fake-blobstore-file-name"))
				})

				It("returns error when downloading package blob fails", func() {
					blobstore.GetError = errors.New("fake-get-error")

					err := act()
					Expect(err).To(HaveOccurred())
					Expect(err.Error()).To(ContainSubstring("fake-get-error"))
				})

				It("decompresses package blob to tmp path and later cleans it up", func() {
					fs.TempDirDir = "/fake-tmp-dir"
					blobstore.GetFileName = "/fake-blobstore-file-name"

					var tmpDirExistsBeforeInstall bool

					bundle.InstallCallBack = func() {
						tmpDirExistsBeforeInstall = true
					}

					err := act()
					Expect(err).ToNot(HaveOccurred())

					Expect(compressor.DecompressFileToDirTarballPaths[0]).To(Equal("/fake-blobstore-file-name"))
					Expect(compressor.DecompressFileToDirDirs[0]).To(Equal("/fake-tmp-dir"))

					// tmp dir exists before bundle install
					Expect(tmpDirExistsBeforeInstall).To(BeTrue())

					// tmp dir is cleaned up after install
					Expect(fs.FileExists(fs.TempDirDir)).To(BeFalse())
				})

				It("returns error when temporary directory creation fails", func() {
					fs.TempDirError = errors.New("fake-filesystem-tempdir-error")

					err := act()
					Expect(err).To(HaveOccurred())
					Expect(err.Error()).To(ContainSubstring("fake-filesystem-tempdir-error"))
				})

				It("returns error when decompressing package blob fails", func() {
					compressor.DecompressFileToDirErr = errors.New("fake-decompress-error")

					err := act()
					Expect(err).To(HaveOccurred())
					Expect(err.Error()).To(ContainSubstring("fake-decompress-error"))
				})

				It("installs bundle from decompressed tmp path of a package blob", func() {
					fs.TempDirDir = "/fake-tmp-dir"

					var installedBeforeDecompression bool

					compressor.DecompressFileToDirCallBack = func() {
						installedBeforeDecompression = bundle.Installed
					}

					err := act()
					Expect(err).ToNot(HaveOccurred())

					// bundle installation did not happen before decompression
					Expect(installedBeforeDecompression).To(BeFalse())

					// make sure that bundle install happened after decompression
					Expect(bundle.InstallSourcePath).To(Equal("/fake-tmp-dir"))
				})
			}

			Describe("Prepare", func() {
				act := func() error { return applier.Prepare(pkg) }

				It("return an error if getting file bundle fails", func() {
					packagesBc.GetErr = errors.New("fake-get-bundle-error")

					err := act()
					Expect(err).To(HaveOccurred())
					Expect(err.Error()).To(ContainSubstring("fake-get-bundle-error"))
				})

				It("returns an error if checking for package installation fails", func() {
					bundle.IsInstalledErr = errors.New("fake-is-installed-error")

					err := act()
					Expect(err).To(HaveOccurred())
					Expect(err.Error()).To(ContainSubstring("fake-is-installed-error"))
				})

				Context("when package is already installed", func() {
					BeforeEach(func() {
						bundle.Installed = true
					})

					It("does not install", func() {
						err := act()
						Expect(err).ToNot(HaveOccurred())
						Expect(bundle.ActionsCalled).To(Equal([]string{})) // no Install
					})

					It("does not download the package", func() {
						err := act()
						Expect(err).ToNot(HaveOccurred())
						Expect(blobstore.GetBlobIDs).To(BeNil())
					})
				})

				Context("when package is not installed", func() {
					BeforeEach(func() {
						bundle.Installed = false
					})

					It("installs package (but does not enable it)", func() {
						err := act()
						Expect(err).ToNot(HaveOccurred())
						Expect(bundle.ActionsCalled).To(Equal([]string{"Install"}))
					})

					ItInstallsPkg(act)
				})
			})

			Describe("Apply", func() {
				act := func() error { return applier.Apply(pkg) }

				It("return an error if getting file bundle fails", func() {
					packagesBc.GetErr = errors.New("fake-get-bundle-error")

					err := act()
					Expect(err).To(HaveOccurred())
					Expect(err.Error()).To(ContainSubstring("fake-get-bundle-error"))
				})

				It("returns an error if checking for package installation fails", func() {
					bundle.IsInstalledErr = errors.New("fake-is-installed-error")

					err := act()
					Expect(err).To(HaveOccurred())
					Expect(err.Error()).To(ContainSubstring("fake-is-installed-error"))
				})

				Context("when package is already installed", func() {
					BeforeEach(func() {
						bundle.Installed = true
					})

					It("does not install but only enables package", func() {
						err := act()
						Expect(err).ToNot(HaveOccurred())
						Expect(bundle.ActionsCalled).To(Equal([]string{"Enable"})) // no Install
					})

					It("returns error when package enable fails", func() {
						bundle.EnableError = errors.New("fake-enable-error")

						err := act()
						Expect(err).To(HaveOccurred())
						Expect(err.Error()).To(ContainSubstring("fake-enable-error"))
					})

					It("does not download the package", func() {
						err := act()
						Expect(err).ToNot(HaveOccurred())
						Expect(blobstore.GetBlobIDs).To(BeNil())
					})
				})

				Context("when package is not installed", func() {
					BeforeEach(func() {
						bundle.Installed = false
					})

					It("installs and enables package", func() {
						err := act()
						Expect(err).ToNot(HaveOccurred())
						Expect(bundle.ActionsCalled).To(Equal([]string{"Install", "Enable"}))
					})

					It("returns error when package enable fails", func() {
						bundle.EnableError = errors.New("fake-enable-error")

						err := act()
						Expect(err).To(HaveOccurred())
						Expect(err.Error()).To(ContainSubstring("fake-enable-error"))
					})

					ItInstallsPkg(act)
				})
			})
		})

		Describe("KeepOnly", func() {
			ItReturnsErrors := func() {
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
			}

			Context("when operating on packages as a package owner", func() {
				BeforeEach(func() {
					applier = NewConcretePackageApplier(packagesBc, true, blobstore, compressor, fs, logger)
				})

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

				ItReturnsErrors()

				It("returns error when at least one bundle cannot be uninstalled", func() {
					_, bundle1 := buildPkg(packagesBc)

					packagesBc.ListBundles = []boshbc.Bundle{bundle1}
					bundle1.UninstallErr = errors.New("fake-bc-uninstall-error")

					err := applier.KeepOnly([]models.Package{})
					Expect(err).To(HaveOccurred())
					Expect(err.Error()).To(ContainSubstring("fake-bc-uninstall-error"))
				})
			})

			Context("when operating on packages not as a package owner", func() {
				BeforeEach(func() {
					applier = NewConcretePackageApplier(packagesBc, false, blobstore, compressor, fs, logger)
				})

				It("disables and but does not uninstall packages that are not in keeponly list", func() {
					_, bundle1 := buildPkg(packagesBc)
					pkg2, bundle2 := buildPkg(packagesBc)
					_, bundle3 := buildPkg(packagesBc)
					pkg4, bundle4 := buildPkg(packagesBc)

					packagesBc.ListBundles = []boshbc.Bundle{bundle1, bundle2, bundle3, bundle4}

					err := applier.KeepOnly([]models.Package{pkg4, pkg2})
					Expect(err).ToNot(HaveOccurred())

					Expect(bundle1.ActionsCalled).To(Equal([]string{"Disable"})) // no Uninstall
					Expect(bundle2.ActionsCalled).To(Equal([]string{}))
					Expect(bundle3.ActionsCalled).To(Equal([]string{"Disable"})) // no Uninstall
					Expect(bundle4.ActionsCalled).To(Equal([]string{}))
				})

				ItReturnsErrors()
			})

		})
	})
}
