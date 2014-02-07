package compiler

import (
	fakebc "bosh/agent/applier/bundlecollection/fakes"
	boshmodels "bosh/agent/applier/models"
	fakepa "bosh/agent/applier/packageapplier/fakes"
	fakeblobstore "bosh/blobstore/fakes"
	fakecmd "bosh/platform/commands/fakes"
	boshdirs "bosh/settings/directories"
	boshsys "bosh/system"
	fakesys "bosh/system/fakes"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestCompileReturnsBlobIdAndSha1(t *testing.T) {
	deps, compiler := buildCompiler()

	deps.blobstore.CreateBlobId = "my-blob-id"
	deps.blobstore.CreateFingerprint = "blob-sha1"
	pkg, pkgDeps := getCompileArgs()

	blobId, sha1, err := compiler.Compile(pkg, pkgDeps)
	assert.NoError(t, err)

	assert.Equal(t, "my-blob-id", blobId)
	assert.Equal(t, "blob-sha1", sha1)
}

func TestCompileFetchesSourcePackageFromBlobstore(t *testing.T) {
	deps, compiler := buildCompiler()

	pkg, pkgDeps := getCompileArgs()

	_, _, err := compiler.Compile(pkg, pkgDeps)
	assert.NoError(t, err)

	assert.Equal(t, "blobstore_id", deps.blobstore.GetBlobIds[0])
	assert.Equal(t, "sha1", deps.blobstore.GetFingerprints[0])
}

func TestCompileInstallsDependentPackages(t *testing.T) {
	deps, compiler := buildCompiler()

	pkg, pkgDeps := getCompileArgs()

	_, _, err := compiler.Compile(pkg, pkgDeps)
	assert.NoError(t, err)

	assert.Equal(t, deps.packageApplier.AppliedPackages, pkgDeps)
}

func TestCompileExtractsSourcePkgToCompileDir(t *testing.T) {
	deps, compiler := buildCompiler()

	pkg, pkgDeps := getCompileArgs()

	deps.blobstore.GetFileName = "/dev/null"

	_, _, err := compiler.Compile(pkg, pkgDeps)
	assert.NoError(t, err)

	assert.True(t, deps.fs.FileExists("/fake-dir/data/compile/pkg_name"))
	assert.Equal(t, deps.compressor.DecompressFileToDirDirs[0], "/fake-dir/data/compile/pkg_name-bosh-agent-unpack")
	assert.Equal(t, deps.compressor.DecompressFileToDirTarballPaths[0], deps.blobstore.GetFileName)

	assert.Equal(t, deps.fs.RenameOldPaths[0], "/fake-dir/data/compile/pkg_name-bosh-agent-unpack")
	assert.Equal(t, deps.fs.RenameNewPaths[0], "/fake-dir/data/compile/pkg_name")
}

func TestCompileInstallsEnablesAndCleansUpBundle(t *testing.T) {
	deps, compiler := buildCompiler()
	pkg, pkgDeps := getCompileArgs()

	_, _, err := compiler.Compile(pkg, pkgDeps)
	assert.NoError(t, err)

	assert.Equal(t, deps.bundle.ActionsCalled, []string{"Install", "Enable", "Disable"})
}

func TestCompileCompressesCompiledPackage(t *testing.T) {
	deps, compiler := buildCompiler()

	pkg, pkgDeps := getCompileArgs()

	_, _, err := compiler.Compile(pkg, pkgDeps)
	assert.NoError(t, err)

	assert.Equal(t, "/fake-dir/data/packages/pkg_name/pkg_version", deps.compressor.CompressFilesInDirDir)
}

func TestCompileWhenScriptDoesNotExist(t *testing.T) {
	deps, compiler := buildCompiler()

	pkg, pkgDeps := getCompileArgs()

	_, _, err := compiler.Compile(pkg, pkgDeps)
	assert.NoError(t, err)

	assert.Empty(t, deps.runner.RunCommands)
}

func TestCompileWhenScriptExists(t *testing.T) {
	deps, compiler := buildCompiler()

	pkg, pkgDeps := getCompileArgs()

	deps.compressor.DecompressFileToDirCallBack = func() {
		deps.fs.WriteToFile("/fake-dir/data/compile/pkg_name/packaging", "hi")
	}

	_, _, err := compiler.Compile(pkg, pkgDeps)
	assert.NoError(t, err)

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

	assert.Equal(t, 1, len(deps.runner.RunComplexCommands))
	assert.Equal(t, expectedCmd, deps.runner.RunComplexCommands[0])
}

func TestCompileUploadsCompressedPackage(t *testing.T) {
	deps, compiler := buildCompiler()

	pkg, pkgDeps := getCompileArgs()

	deps.compressor.CompressFilesInDirTarballPath = "/tmp/foo"

	_, _, err := compiler.Compile(pkg, pkgDeps)
	assert.NoError(t, err)
	assert.Equal(t, "/tmp/foo", deps.blobstore.CreateFileName)
}

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
