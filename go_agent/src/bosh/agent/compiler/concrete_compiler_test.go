package compiler_test

import (
	"errors"
	"os"
	"time"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	fakebc "bosh/agent/applier/bundlecollection/fakes"
	boshmodels "bosh/agent/applier/models"
	fakepa "bosh/agent/applier/packageapplier/fakes"
	. "bosh/agent/compiler"
	fakeblobstore "bosh/blobstore/fakes"
	fakecmd "bosh/platform/commands/fakes"
	boshsys "bosh/system"
	fakesys "bosh/system/fakes"
)

type FakeCompileDirProvider struct {
	Dir string
}

func (cdp FakeCompileDirProvider) CompileDir() string { return cdp.Dir }

func getCompileArgs() (Package, []boshmodels.Package) {
	pkg := Package{
		BlobstoreID: "blobstore_id",
		Sha1:        "sha1",
		Name:        "pkg_name",
		Version:     "pkg_version",
	}

	pkgDeps := []boshmodels.Package{
		{
			Name:    "first_dep_name",
			Version: "first_dep_version",
			Source: boshmodels.Source{
				Sha1:        "first_dep_sha1",
				BlobstoreID: "first_dep_blobstore_id",
			},
		},
		{
			Name:    "sec_dep_name",
			Version: "sec_dep_version",
			Source: boshmodels.Source{
				Sha1:        "sec_dep_sha1",
				BlobstoreID: "sec_dep_blobstore_id",
			},
		},
	}

	return pkg, pkgDeps
}

func init() {
	Describe("concreteCompiler", func() {
		var (
			compiler       Compiler
			compressor     *fakecmd.FakeCompressor
			blobstore      *fakeblobstore.FakeBlobstore
			fs             *fakesys.FakeFileSystem
			runner         *fakesys.FakeCmdRunner
			packageApplier *fakepa.FakePackageApplier
			packagesBc     *fakebc.FakeBundleCollection
		)

		BeforeEach(func() {
			compressor = fakecmd.NewFakeCompressor()
			blobstore = &fakeblobstore.FakeBlobstore{}
			fs = fakesys.NewFakeFileSystem()
			runner = fakesys.NewFakeCmdRunner()
			packageApplier = fakepa.NewFakePackageApplier()
			packagesBc = fakebc.NewFakeBundleCollection()

			compiler = NewConcreteCompiler(
				compressor,
				blobstore,
				fs,
				runner,
				FakeCompileDirProvider{Dir: "/fake-compile-dir"},
				packageApplier,
				packagesBc,
			)
		})

		BeforeEach(func() {
			fs.MkdirAll("/fake-compile-dir", os.ModePerm)
		})

		Describe("Compile", func() {
			var (
				bundle  *fakebc.FakeBundle
				pkg     Package
				pkgDeps []boshmodels.Package
			)

			BeforeEach(func() {
				bundle = packagesBc.FakeGet(boshmodels.Package{
					Name:    "pkg_name",
					Version: "pkg_version",
				})

				bundle.InstallPath = "/fake-dir/data/packages/pkg_name/pkg_version"
				bundle.EnablePath = "/fake-dir/packages/pkg_name"

				compressor.CompressFilesInDirTarballPath = "/tmp/compressed-compiled-package"

				pkg, pkgDeps = getCompileArgs()
			})

			It("returns blob id and sha1 of created compiled package", func() {
				blobstore.CreateBlobID = "fake-blob-id"
				blobstore.CreateFingerprint = "fake-blob-sha1"

				blobID, sha1, err := compiler.Compile(pkg, pkgDeps)
				Expect(err).ToNot(HaveOccurred())

				Expect(blobID).To(Equal("fake-blob-id"))
				Expect(sha1).To(Equal("fake-blob-sha1"))
			})

			It("cleans up all packages before applying dependent packages", func() {
				_, _, err := compiler.Compile(pkg, pkgDeps)
				Expect(err).ToNot(HaveOccurred())
				Expect(packageApplier.ActionsCalled).To(Equal([]string{"KeepOnly", "Apply", "Apply"}))
				Expect(packageApplier.KeptOnlyPackages).To(BeEmpty())
			})

			It("returns an error if cleaning up packages fails", func() {
				packageApplier.KeepOnlyErr = errors.New("fake-keep-only-error")

				_, _, err := compiler.Compile(pkg, pkgDeps)
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("fake-keep-only-error"))
			})

			It("fetches source package from blobstore without checking SHA1 by default because of Director bug", func() {
				_, _, err := compiler.Compile(pkg, pkgDeps)
				Expect(err).ToNot(HaveOccurred())

				Expect(blobstore.GetBlobIDs[0]).To(Equal("blobstore_id"))
				Expect(blobstore.GetFingerprints[0]).To(Equal(""))
			})

			It("fetches source package from blobstore and checks SHA1 by default in future", func() {
				_, _, err := compiler.Compile(pkg, pkgDeps)
				Expect(err).ToNot(HaveOccurred())

				Expect(blobstore.GetBlobIDs[0]).To(Equal("blobstore_id"))

				// Wait for some time fixing default SHA1 check to stay backwards compatible
				fixDeadline := time.Date(2014, time.September, 22, 6, 0, 0, 0, time.UTC)

				if time.Now().After(fixDeadline) {
					Expect(blobstore.GetFingerprints[0]).To(Equal("sha1"))
				}
			})

			It("returns an error if removing compile target directory during uncompression fails", func() {
				fs.RegisterRemoveAllError("/fake-compile-dir/pkg_name", errors.New("fake-remove-error"))

				_, _, err := compiler.Compile(pkg, pkgDeps)
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("fake-remove-error"))
			})

			It("returns an error if creating compile target directory during uncompression fails", func() {
				fs.RegisterMkdirAllError("/fake-compile-dir/pkg_name", errors.New("fake-mkdir-error"))

				_, _, err := compiler.Compile(pkg, pkgDeps)
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("fake-mkdir-error"))
			})

			It("returns an error if removing temporary compile target directory during uncompression fails", func() {
				fs.RegisterRemoveAllError("/fake-compile-dir/pkg_name-bosh-agent-unpack", errors.New("fake-remove-error"))

				_, _, err := compiler.Compile(pkg, pkgDeps)
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("fake-remove-error"))
			})

			It("returns an error if creating temporary compile target directory during uncompression fails", func() {
				fs.RegisterMkdirAllError("/fake-compile-dir/pkg_name-bosh-agent-unpack", errors.New("fake-mkdir-error"))

				_, _, err := compiler.Compile(pkg, pkgDeps)
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("fake-mkdir-error"))
			})

			It("installs dependent packages", func() {
				_, _, err := compiler.Compile(pkg, pkgDeps)
				Expect(err).ToNot(HaveOccurred())
				Expect(packageApplier.AppliedPackages).To(Equal(pkgDeps))
			})

			It("extracts source package to compile dir", func() {
				_, _, err := compiler.Compile(pkg, pkgDeps)
				Expect(err).ToNot(HaveOccurred())

				Expect(fs.FileExists("/fake-compile-dir/pkg_name")).To(BeTrue())
				Expect(compressor.DecompressFileToDirDirs[0]).To(Equal("/fake-compile-dir/pkg_name-bosh-agent-unpack"))
				Expect(compressor.DecompressFileToDirTarballPaths[0]).To(Equal(blobstore.GetFileName))

				Expect(fs.RenameOldPaths[0]).To(Equal("/fake-compile-dir/pkg_name-bosh-agent-unpack"))
				Expect(fs.RenameNewPaths[0]).To(Equal("/fake-compile-dir/pkg_name"))
			})

			It("installs, enables and later cleans up bundle", func() {
				_, _, err := compiler.Compile(pkg, pkgDeps)
				Expect(err).ToNot(HaveOccurred())
				Expect(bundle.ActionsCalled).To(Equal([]string{
					"InstallWithoutContents",
					"Enable",
					"Disable",
					"Uninstall",
				}))
			})

			It("runs packaging script when packaging script exists", func() {
				compressor.DecompressFileToDirCallBack = func() {
					fs.WriteFileString("/fake-compile-dir/pkg_name/packaging", "hi")
				}

				_, _, err := compiler.Compile(pkg, pkgDeps)
				Expect(err).ToNot(HaveOccurred())

				expectedCmd := boshsys.Command{
					Name: "bash",
					Args: []string{"-x", "packaging"},
					Env: map[string]string{
						"BOSH_COMPILE_TARGET":  "/fake-compile-dir/pkg_name",
						"BOSH_INSTALL_TARGET":  "/fake-dir/packages/pkg_name",
						"BOSH_PACKAGE_NAME":    "pkg_name",
						"BOSH_PACKAGE_VERSION": "pkg_version",
					},
					WorkingDir: "/fake-compile-dir/pkg_name",
				}

				Expect(len(runner.RunComplexCommands)).To(Equal(1))
				Expect(runner.RunComplexCommands[0]).To(Equal(expectedCmd))
			})

			It("does not run packaging script when script does not exist", func() {
				_, _, err := compiler.Compile(pkg, pkgDeps)
				Expect(err).ToNot(HaveOccurred())
				Expect(runner.RunCommands).To(BeEmpty())
			})

			It("compresses compiled package", func() {
				_, _, err := compiler.Compile(pkg, pkgDeps)
				Expect(err).ToNot(HaveOccurred())
				Expect(compressor.CompressFilesInDirDir).To(Equal("/fake-dir/data/packages/pkg_name/pkg_version"))
			})

			It("uploads compressed package to blobstore", func() {
				compressor.CompressFilesInDirTarballPath = "/tmp/compressed-compiled-package"

				_, _, err := compiler.Compile(pkg, pkgDeps)
				Expect(err).ToNot(HaveOccurred())
				Expect(blobstore.CreateFileName).To(Equal("/tmp/compressed-compiled-package"))
			})

			It("returs error if uploading compressed package fails", func() {
				blobstore.CreateErr = errors.New("fake-create-err")

				_, _, err := compiler.Compile(pkg, pkgDeps)
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("fake-create-err"))
			})

			It("cleans up compressed package after uploading it to blobstore", func() {
				var beforeCleanUpTarballPath, afterCleanUpTarballPath string

				blobstore.CreateCallBack = func() {
					beforeCleanUpTarballPath = compressor.CleanUpTarballPath
				}

				_, _, err := compiler.Compile(pkg, pkgDeps)
				Expect(err).ToNot(HaveOccurred())

				// Compressed package is not cleaned up before blobstore upload
				Expect(beforeCleanUpTarballPath).To(Equal(""))

				// Deleted after it was uploaded
				afterCleanUpTarballPath = compressor.CleanUpTarballPath
				Expect(afterCleanUpTarballPath).To(Equal("/tmp/compressed-compiled-package"))
			})
		})
	})
}
