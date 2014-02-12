package compiler_test

import (
	fakebc "bosh/agent/applier/bundlecollection/fakes"
	boshmodels "bosh/agent/applier/models"
	fakepa "bosh/agent/applier/packageapplier/fakes"
	. "bosh/agent/compiler"
	fakeblobstore "bosh/blobstore/fakes"
	fakecmd "bosh/platform/commands/fakes"
	boshdirs "bosh/settings/directories"
	boshsys "bosh/system"
	fakesys "bosh/system/fakes"
	. "github.com/onsi/ginkgo"
	"github.com/stretchr/testify/assert"
)

func getCompileArgs() (pkg Package, pkgDeps []boshmodels.Package) {
	pkg = Package{
		BlobstoreId: "blobstore_id",
		Sha1:        "sha1",
		Name:        "pkg_name",
		Version:     "pkg_version",
	}
	pkgDeps = []boshmodels.Package{
		{
			Name:    "first_dep",
			Version: "first_dep_version",
			Source: boshmodels.Source{
				Sha1:        "first_dep_sha1",
				BlobstoreId: "first_dep_blobstore_id",
			},
		},
		{
			Name:    "sec_dep",
			Version: "sec_dep_version",
			Source: boshmodels.Source{
				Sha1:        "sec_dep_sha1",
				BlobstoreId: "sec_dep_blobstore_id",
			},
		},
	}
	return
}

type compilerDeps struct {
	compressor     *fakecmd.FakeCompressor
	blobstore      *fakeblobstore.FakeBlobstore
	fs             *fakesys.FakeFileSystem
	runner         *fakesys.FakeCmdRunner
	packageApplier *fakepa.FakePackageApplier
	packagesBc     *fakebc.FakeBundleCollection
	bundle         *fakebc.FakeBundle
}

func buildCompiler() (
	deps compilerDeps,
	compiler Compiler,
) {
	deps.compressor = fakecmd.NewFakeCompressor()
	deps.blobstore = &fakeblobstore.FakeBlobstore{}
	deps.fs = fakesys.NewFakeFileSystem()
	deps.runner = fakesys.NewFakeCmdRunner()
	deps.packageApplier = fakepa.NewFakePackageApplier()
	fakeBundleCollection := fakebc.NewFakeBundleCollection()
	bundleDefinition := boshmodels.Package{
		Name:    "pkg_name",
		Version: "pkg_version",
	}
	deps.bundle = fakeBundleCollection.FakeGet(bundleDefinition)
	deps.bundle.InstallPath = "/fake-dir/data/packages/pkg_name/pkg_version"
	deps.bundle.EnablePath = "/fake-dir/packages/pkg_name"
	deps.packagesBc = fakeBundleCollection

	compiler = NewConcreteCompiler(
		deps.compressor,
		deps.blobstore,
		deps.fs,
		deps.runner,
		boshdirs.NewDirectoriesProvider("/fake-dir"),
		deps.packageApplier,
		deps.packagesBc,
	)
	return
}
func init() {
	Describe("Testing with Ginkgo", func() {
		It("compile returns blob id and sha1", func() {
			deps, compiler := buildCompiler()

			deps.blobstore.CreateBlobId = "my-blob-id"
			deps.blobstore.CreateFingerprint = "blob-sha1"
			pkg, pkgDeps := getCompileArgs()

			blobId, sha1, err := compiler.Compile(pkg, pkgDeps)
			assert.NoError(GinkgoT(), err)

			assert.Equal(GinkgoT(), "my-blob-id", blobId)
			assert.Equal(GinkgoT(), "blob-sha1", sha1)
		})
		It("compile fetches source package from blobstore", func() {

			deps, compiler := buildCompiler()

			pkg, pkgDeps := getCompileArgs()

			_, _, err := compiler.Compile(pkg, pkgDeps)
			assert.NoError(GinkgoT(), err)

			assert.Equal(GinkgoT(), "blobstore_id", deps.blobstore.GetBlobIds[0])
			assert.Equal(GinkgoT(), "sha1", deps.blobstore.GetFingerprints[0])
		})
		It("compile installs dependent packages", func() {

			deps, compiler := buildCompiler()

			pkg, pkgDeps := getCompileArgs()

			_, _, err := compiler.Compile(pkg, pkgDeps)
			assert.NoError(GinkgoT(), err)

			assert.Equal(GinkgoT(), deps.packageApplier.AppliedPackages, pkgDeps)
		})
		It("compile extracts source pkg to compile dir", func() {

			deps, compiler := buildCompiler()

			pkg, pkgDeps := getCompileArgs()

			deps.blobstore.GetFileName = "/dev/null"

			_, _, err := compiler.Compile(pkg, pkgDeps)
			assert.NoError(GinkgoT(), err)

			assert.True(GinkgoT(), deps.fs.FileExists("/fake-dir/data/compile/pkg_name"))
			assert.Equal(GinkgoT(), deps.compressor.DecompressFileToDirDirs[0], "/fake-dir/data/compile/pkg_name-bosh-agent-unpack")
			assert.Equal(GinkgoT(), deps.compressor.DecompressFileToDirTarballPaths[0], deps.blobstore.GetFileName)

			assert.Equal(GinkgoT(), deps.fs.RenameOldPaths[0], "/fake-dir/data/compile/pkg_name-bosh-agent-unpack")
			assert.Equal(GinkgoT(), deps.fs.RenameNewPaths[0], "/fake-dir/data/compile/pkg_name")
		})
		It("compile installs enables and cleans up bundle", func() {

			deps, compiler := buildCompiler()
			pkg, pkgDeps := getCompileArgs()

			_, _, err := compiler.Compile(pkg, pkgDeps)
			assert.NoError(GinkgoT(), err)

			assert.Equal(GinkgoT(), deps.bundle.ActionsCalled, []string{"Install", "Enable", "Disable", "Uninstall"})
		})
		It("compile compresses compiled package", func() {

			deps, compiler := buildCompiler()

			pkg, pkgDeps := getCompileArgs()

			_, _, err := compiler.Compile(pkg, pkgDeps)
			assert.NoError(GinkgoT(), err)

			assert.Equal(GinkgoT(), "/fake-dir/data/packages/pkg_name/pkg_version", deps.compressor.CompressFilesInDirDir)
		})
		It("compile when script does not exist", func() {

			deps, compiler := buildCompiler()

			pkg, pkgDeps := getCompileArgs()

			_, _, err := compiler.Compile(pkg, pkgDeps)
			assert.NoError(GinkgoT(), err)

			assert.Empty(GinkgoT(), deps.runner.RunCommands)
		})
		It("compile when script exists", func() {

			deps, compiler := buildCompiler()

			pkg, pkgDeps := getCompileArgs()

			deps.compressor.DecompressFileToDirCallBack = func() {
				deps.fs.WriteToFile("/fake-dir/data/compile/pkg_name/packaging", "hi")
			}

			_, _, err := compiler.Compile(pkg, pkgDeps)
			assert.NoError(GinkgoT(), err)

			expectedCmd := boshsys.Command{
				Name: "bash",
				Args: []string{"-x", "packaging"},
				Env: map[string]string{
					"BOSH_COMPILE_TARGET":  "/fake-dir/data/compile/pkg_name",
					"BOSH_INSTALL_TARGET":  "/fake-dir/packages/pkg_name",
					"BOSH_PACKAGE_NAME":    "pkg_name",
					"BOSH_PACKAGE_VERSION": "pkg_version",
				},
				WorkingDir: "/fake-dir/data/compile/pkg_name",
			}

			assert.Equal(GinkgoT(), 1, len(deps.runner.RunComplexCommands))
			assert.Equal(GinkgoT(), expectedCmd, deps.runner.RunComplexCommands[0])
		})
		It("compile uploads compressed package", func() {

			deps, compiler := buildCompiler()

			pkg, pkgDeps := getCompileArgs()

			deps.compressor.CompressFilesInDirTarballPath = "/tmp/foo"

			_, _, err := compiler.Compile(pkg, pkgDeps)
			assert.NoError(GinkgoT(), err)
			assert.Equal(GinkgoT(), "/tmp/foo", deps.blobstore.CreateFileName)
		})
	})
}
