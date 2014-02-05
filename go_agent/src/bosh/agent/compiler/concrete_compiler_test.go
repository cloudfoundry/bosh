package compiler

import (
	boshmodels "bosh/agent/applier/models"
	fakepa "bosh/agent/applier/packageapplier/fakes"
	fakeblobstore "bosh/blobstore/fakes"
	fakecmd "bosh/platform/commands/fakes"
	boshdirs "bosh/settings/directories"
	boshsys "bosh/system"
	fakesys "bosh/system/fakes"
	"github.com/stretchr/testify/assert"
	"os"
	"testing"
)

func TestCompileReturnsBlobIdAndSha1(t *testing.T) {
	_, blobstore, _, _, _, compiler := buildCompiler()

	blobstore.CreateBlobId = "my-blob-id"
	blobstore.CreateFingerprint = "blob-sha1"
	pkg, deps := getCompileArgs()

	blobId, sha1, err := compiler.Compile(pkg, deps)
	assert.NoError(t, err)

	assert.Equal(t, "my-blob-id", blobId)
	assert.Equal(t, "blob-sha1", sha1)
}

func TestCompileFetchesSourcePackageFromBlobstore(t *testing.T) {
	_, blobstore, _, _, _, compiler := buildCompiler()

	pkg, deps := getCompileArgs()

	_, _, err := compiler.Compile(pkg, deps)
	assert.NoError(t, err)

	assert.Equal(t, "blobstore_id", blobstore.GetBlobIds[0])
	assert.Equal(t, "sha1", blobstore.GetFingerprints[0])
}

func TestCompileInstallsDependentPackages(t *testing.T) {
	_, _, _, _, packageApplier, compiler := buildCompiler()

	pkg, deps := getCompileArgs()

	_, _, err := compiler.Compile(pkg, deps)
	assert.NoError(t, err)

	assert.Equal(t, packageApplier.AppliedPackages, deps)
}

func TestCompileExtractsSourcePkgToCompileDir(t *testing.T) {
	compressor, blobstore, fs, _, _, compiler := buildCompiler()

	pkg, deps := getCompileArgs()

	blobstore.GetFileName = "/dev/null"

	_, _, err := compiler.Compile(pkg, deps)
	assert.NoError(t, err)

	assert.True(t, fs.FileExists("/fake-dir/data/compile/pkg_name"))
	assert.Equal(t, compressor.DecompressFileToDirDirs[0], "/fake-dir/data/compile/pkg_name-bosh-agent-unpack")
	assert.Equal(t, compressor.DecompressFileToDirTarballPaths[0], blobstore.GetFileName)

	assert.Equal(t, fs.RenameOldPaths[0], "/fake-dir/data/compile/pkg_name-bosh-agent-unpack")
	assert.Equal(t, fs.RenameNewPaths[0], "/fake-dir/data/compile/pkg_name")
}

func TestCompileCreatesInstallDir(t *testing.T) {
	_, _, fs, _, _, compiler := buildCompiler()

	pkg, deps := getCompileArgs()

	installDir := "/fake-dir/data/packages/pkg_name/pkg_version"

	assert.False(t, fs.FileExists(installDir))

	_, _, err := compiler.Compile(pkg, deps)
	assert.NoError(t, err)

	assert.True(t, fs.FileExists(installDir))
	installDirStats := fs.GetFileTestStat(installDir)
	assert.Equal(t, os.FileMode(0755), installDirStats.FileMode.Perm())
}

func TestCompileRecreatesInstallDir(t *testing.T) {
	_, _, fs, _, _, compiler := buildCompiler()

	pkg, deps := getCompileArgs()

	err := fs.MkdirAll("/fake-dir/data/packages/pkg_name/pkg_version", os.FileMode(0755))
	assert.NoError(t, err)

	_, err = fs.WriteToFile("/fake-dir/data/packages/pkg_name/pkg_version/should_be_deleted", "test")
	assert.NoError(t, err)

	assert.True(t, fs.FileExists("/fake-dir/data/packages/pkg_name/pkg_version/should_be_deleted"))

	_, _, err = compiler.Compile(pkg, deps)
	assert.NoError(t, err)

	assert.False(t, fs.FileExists("/fake-dir/data/packages/pkg_name/pkg_version/should_be_deleted"))
}

func TestCompileSymlinksInstallDir(t *testing.T) {
	_, _, fs, _, _, compiler := buildCompiler()

	pkg, deps := getCompileArgs()

	_, _, err := compiler.Compile(pkg, deps)
	assert.NoError(t, err)

	fileStats := fs.GetFileTestStat("/fake-dir/packages/pkg_name")
	assert.NotNil(t, fileStats)
	assert.Equal(t, fakesys.FakeFileTypeSymlink, fileStats.FileType)
	assert.Equal(t, "/fake-dir/data/packages/pkg_name/pkg_version", fileStats.SymlinkTarget)
}

func TestCompileCompressesCompiledPackage(t *testing.T) {
	compressor, _, _, _, _, compiler := buildCompiler()

	pkg, deps := getCompileArgs()

	_, _, err := compiler.Compile(pkg, deps)
	assert.NoError(t, err)

	assert.Equal(t, "/fake-dir/data/packages/pkg_name/pkg_version", compressor.CompressFilesInDirDir)
}

func TestCompileWhenScriptDoesNotExist(t *testing.T) {
	_, _, _, runner, _, compiler := buildCompiler()

	pkg, deps := getCompileArgs()

	_, _, err := compiler.Compile(pkg, deps)
	assert.NoError(t, err)

	assert.Empty(t, runner.RunCommands)
}

func TestCompileWhenScriptExists(t *testing.T) {
	compressor, _, fs, runner, _, compiler := buildCompiler()

	pkg, deps := getCompileArgs()

	compressor.DecompressFileToDirCallBack = func() {
		fs.WriteToFile("/fake-dir/data/compile/pkg_name/packaging", "hi")
	}

	_, _, err := compiler.Compile(pkg, deps)
	assert.NoError(t, err)

	expectedCmd := boshsys.Command{
		Name: "bash",
		Args: []string{"-x", "packaging"},
		Env: map[string]string{
			"BOSH_COMPILE_TARGET":  "/fake-dir/data/compile/pkg_name",
			"BOSH_INSTALL_TARGET":  "/fake-dir/data/packages/pkg_name/pkg_version",
			"BOSH_PACKAGE_NAME":    "pkg_name",
			"BOSH_PACKAGE_VERSION": "pkg_version",
		},
		WorkingDir: "/fake-dir/data/compile/pkg_name",
	}

	assert.Equal(t, 1, len(runner.RunComplexCommands))
	assert.Equal(t, expectedCmd, runner.RunComplexCommands[0])
}

func TestCompileUploadsCompressedPackage(t *testing.T) {
	compressor, blobstore, _, _, _, compiler := buildCompiler()

	pkg, deps := getCompileArgs()

	compressor.CompressFilesInDirTarballPath = "/tmp/foo"

	_, _, err := compiler.Compile(pkg, deps)
	assert.NoError(t, err)
	assert.Equal(t, "/tmp/foo", blobstore.CreateFileName)
}

func getCompileArgs() (pkg Package, deps []boshmodels.Package) {
	pkg = Package{
		BlobstoreId: "blobstore_id",
		Sha1:        "sha1",
		Name:        "pkg_name",
		Version:     "pkg_version",
	}
	deps = []boshmodels.Package{
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

func buildCompiler() (
	compressor *fakecmd.FakeCompressor,
	blobstore *fakeblobstore.FakeBlobstore,
	fs *fakesys.FakeFileSystem,
	runner *fakesys.FakeCmdRunner,
	packageApplier *fakepa.FakePackageApplier,
	compiler Compiler,
) {
	compressor = fakecmd.NewFakeCompressor()
	blobstore = &fakeblobstore.FakeBlobstore{}
	fs = fakesys.NewFakeFileSystem()
	runner = fakesys.NewFakeCmdRunner()
	packageApplier = fakepa.NewFakePackageApplier()
	compiler = NewConcreteCompiler(compressor, blobstore, fs, runner, boshdirs.NewDirectoriesProvider("/fake-dir"), packageApplier)
	return
}
