package action

import (
	fakeblobstore "bosh/blobstore/fakes"
	fakedisk "bosh/platform/disk/fakes"
	fakeplatform "bosh/platform/fakes"
	fakesys "bosh/system/fakes"
	"github.com/stretchr/testify/assert"
	"os"
	"testing"
)

func TestCompilePackageShouldBeAsynchronous(t *testing.T) {
	_, _, action, _, _ := buildCompilePackageAction()
	assert.True(t, action.IsAsynchronous())
}

func TestCompilePackageFetchesSourcePackageFromBlobstore(t *testing.T) {
	_, blobstore, action, _, _ := buildCompilePackageAction()

	blobId, sha1, name, version, deps := getTestArguments()

	_, err := action.Run(blobId, sha1, name, version, deps)
	assert.NoError(t, err)

	assert.Equal(t, "first_dep_blobstore_id", blobstore.GetBlobIds[0])
	assert.Equal(t, "sec_dep_blobstore_id", blobstore.GetBlobIds[1])
	assert.Equal(t, "blobstore_id", blobstore.GetBlobIds[2])
}

func TestCompilePackageExtractsDependenciesToPackagesDir(t *testing.T) {
	compressor, blobstore, action, fs, _ := buildCompilePackageAction()

	blobId, sha1, name, version, deps := getTestArguments()

	file, err := os.Open("/dev/null")
	assert.NoError(t, err)
	defer file.Close()

	blobstore.GetFile = file

	_, err = action.Run(blobId, sha1, name, version, deps)
	assert.NoError(t, err)

	assert.Equal(t, compressor.DecompressFileToDirDirs[0],
		"/var/vcap/data/packages/first_dep/first_dep_version-bosh-agent-unpack")
	assert.Equal(t, compressor.DecompressFileToDirDirs[1],
		"/var/vcap/data/packages/sec_dep/sec_dep_version-bosh-agent-unpack")

	assert.Equal(t, compressor.DecompressFileToDirTarballs[0], file)
	assert.Equal(t, compressor.DecompressFileToDirTarballs[1], file)

	assert.Equal(t, "/var/vcap/data/packages/first_dep/first_dep_version-bosh-agent-unpack", fs.RenameOldPaths[0])
	assert.Equal(t, "/var/vcap/data/packages/sec_dep/sec_dep_version-bosh-agent-unpack", fs.RenameOldPaths[1])

	assert.Equal(t, "/var/vcap/data/packages/first_dep/first_dep_version", fs.RenameNewPaths[0])
	assert.Equal(t, "/var/vcap/data/packages/sec_dep/sec_dep_version", fs.RenameNewPaths[1])
}

func TestCompilePackageCreatesDependencyInstallDir(t *testing.T) {
	_, _, action, fs, _ := buildCompilePackageAction()

	blobId, sha1, name, version, deps := getTestArguments()

	assert.False(t, fs.FileExists("/var/vcap/data/packages/first_dep/first_dep_version"))
	assert.False(t, fs.FileExists("/var/vcap/data/packages/sec_dep/sec_dep_version"))

	_, err := action.Run(blobId, sha1, name, version, deps)
	assert.NoError(t, err)

	assert.True(t, fs.FileExists("/var/vcap/data/packages/first_dep/first_dep_version"))
	assert.True(t, fs.FileExists("/var/vcap/data/packages/sec_dep/sec_dep_version"))
}

func TestCompilePackageRecreatesDependencyInstallDir(t *testing.T) {
	_, _, action, fs, _ := buildCompilePackageAction()

	blobId, sha1, name, version, deps := getTestArguments()

	err := fs.MkdirAll("/var/vcap/data/packages/first_dep/first_dep_version", os.FileMode(0700))
	assert.NoError(t, err)

	_, err = fs.WriteToFile("/var/vcap/data/packages/first_dep/first_dep_version/should_be_deleted", "test")
	assert.NoError(t, err)

	assert.True(t, fs.FileExists("/var/vcap/data/packages/first_dep/first_dep_version/should_be_deleted"))

	_, err = action.Run(blobId, sha1, name, version, deps)
	assert.NoError(t, err)

	assert.False(t, fs.FileExists("/var/vcap/data/packages/first_dep/first_dep_version/should_be_deleted"))
}

func TestCompilePackageExtractsSourcePkgToCompileDir(t *testing.T) {
	compressor, blobstore, action, fs, _ := buildCompilePackageAction()

	blobId, sha1, name, version, deps := getTestArguments()

	file, err := os.Open("/dev/null")
	assert.NoError(t, err)
	defer file.Close()

	blobstore.GetFile = file

	_, err = action.Run(blobId, sha1, name, version, deps)
	assert.NoError(t, err)

	assert.True(t, fs.FileExists("/var/vcap/data/compile/pkg_name"))
	assert.Equal(t, compressor.DecompressFileToDirDirs[2], "/var/vcap/data/compile/pkg_name-bosh-agent-unpack")
	assert.Equal(t, compressor.DecompressFileToDirTarballs[2], file)

	assert.Equal(t, fs.RenameOldPaths[2], "/var/vcap/data/compile/pkg_name-bosh-agent-unpack")
	assert.Equal(t, fs.RenameNewPaths[2], "/var/vcap/data/compile/pkg_name")
}

func TestCompilePackageCreatesInstallDir(t *testing.T) {
	_, _, action, fs, _ := buildCompilePackageAction()

	blobId, sha1, name, version, deps := getTestArguments()

	assert.False(t, fs.FileExists("/var/vcap/data/packages/pkg_name/pkg_version"))

	_, err := action.Run(blobId, sha1, name, version, deps)
	assert.NoError(t, err)

	assert.True(t, fs.FileExists("/var/vcap/data/packages/pkg_name/pkg_version"))
}

func TestCompilePackageRecreatesInstallDir(t *testing.T) {
	_, _, action, fs, _ := buildCompilePackageAction()

	blobId, sha1, name, version, deps := getTestArguments()

	err := fs.MkdirAll("/var/vcap/data/packages/pkg_name/pkg_version", os.FileMode(0700))
	assert.NoError(t, err)

	_, err = fs.WriteToFile("/var/vcap/data/packages/pkg_name/pkg_version/should_be_deleted", "test")
	assert.NoError(t, err)

	assert.True(t, fs.FileExists("/var/vcap/data/packages/pkg_name/pkg_version/should_be_deleted"))

	_, err = action.Run(blobId, sha1, name, version, deps)
	assert.NoError(t, err)

	assert.False(t, fs.FileExists("/var/vcap/data/packages/pkg_name/pkg_version/should_be_deleted"))
}

func TestCompilePackageSymlinksInstallDir(t *testing.T) {
	_, _, action, fs, _ := buildCompilePackageAction()

	blobId, sha1, name, version, deps := getTestArguments()

	_, err := action.Run(blobId, sha1, name, version, deps)
	assert.NoError(t, err)

	fileStats := fs.GetFileTestStat("/var/vcap/packages/pkg_name")
	assert.NotNil(t, fileStats)
	assert.Equal(t, fakesys.FakeFileTypeSymlink, fileStats.FileType)
	assert.Equal(t, "/var/vcap/data/packages/pkg_name/pkg_version", fileStats.SymlinkTarget)
}

func TestCompilePackageSetsUpEnvironmentVariables(t *testing.T) {
	_, _, action, _, _ := buildCompilePackageAction()

	blobId, sha1, name, version, deps := getTestArguments()

	clearEnvVariables()

	assert.Empty(t, os.Getenv("BOSH_COMPILE_TARGET"))
	assert.Empty(t, os.Getenv("BOSH_INSTALL_TARGET"))
	assert.Empty(t, os.Getenv("BOSH_PACKAGE_NAME"))
	assert.Empty(t, os.Getenv("BOSH_PACKAGE_VERSION"))

	_, err := action.Run(blobId, sha1, name, version, deps)
	assert.NoError(t, err)

	assert.Equal(t, "/var/vcap/data/compile/pkg_name", os.Getenv("BOSH_COMPILE_TARGET"))
	assert.Equal(t, "/var/vcap/packages/pkg_name", os.Getenv("BOSH_INSTALL_TARGET"))
	assert.Equal(t, "pkg_name", os.Getenv("BOSH_PACKAGE_NAME"))
	assert.Equal(t, "pkg_version", os.Getenv("BOSH_PACKAGE_VERSION"))

	assert.Empty(t, os.Getenv("GEM_HOME"))
	assert.Empty(t, os.Getenv("BUNDLE_GEMFILE"))
	assert.Empty(t, os.Getenv("RUBYOPT"))
}

func TestCompilePackageCompressesCompiledPackage(t *testing.T) {
	compressor, _, action, _, _ := buildCompilePackageAction()

	blobId, sha1, name, version, deps := getTestArguments()

	_, err := action.Run(blobId, sha1, name, version, deps)
	assert.NoError(t, err)

	assert.Equal(t, "/var/vcap/data/packages/pkg_name/pkg_version", compressor.CompressFilesInDirDir)
	assert.Equal(t, []string{"**/*"}, compressor.CompressFilesInDirFilters)
}

func TestCompilePackageScriptDoesNotExist(t *testing.T) {
	_, _, action, _, platform := buildCompilePackageAction()

	blobId, sha1, name, version, deps := getTestArguments()

	_, err := action.Run(blobId, sha1, name, version, deps)
	assert.NoError(t, err)

	assert.Empty(t, platform.Runner.RunCommands)
}

func TestCompilePackageScriptExists(t *testing.T) {
	_, _, action, fs, platform := buildCompilePackageAction()

	blobId, sha1, name, version, deps := getTestArguments()

	fs.WriteToFile("/var/vcap/data/compile/pkg_name/packaging", "hi")

	_, err := action.Run(blobId, sha1, name, version, deps)
	assert.NoError(t, err)

	assert.Equal(t, platform.Runner.RunCommands,
		[][]string{{"cd", "/var/vcap/data/compile/pkg_name", "&&", "bash", "-x", "packaging", "2>&1"}})
}

func clearEnvVariables() {
	os.Setenv("BOSH_COMPILE_TARGET", "")
	os.Setenv("BOSH_INSTALL_TARGET", "")
	os.Setenv("BOSH_PACKAGE_NAME", "")
	os.Setenv("BOSH_PACKAGE_VERSION", "")
}

func getTestArguments() (blobId, sha1, name, version string, deps Dependencies) {
	blobId = "blobstore_id"
	sha1 = "sha1"
	name = "pkg_name"
	version = "pkg_version"
	deps = Dependencies{
		"first_dep": Dependency{
			BlobstoreId: "first_dep_blobstore_id",
			Name:        "first_dep",
			Sha1:        "first_dep_sha1",
			Version:     "first_dep_version",
		},
		"sec_dep": Dependency{
			BlobstoreId: "sec_dep_blobstore_id",
			Name:        "sec_dep",
			Sha1:        "sec_dep_sha1",
			Version:     "sec_dep_version",
		},
	}
	return
}

func buildCompilePackageAction() (*fakedisk.FakeCompressor, *fakeblobstore.FakeBlobstore, compilePackageAction, *fakesys.FakeFileSystem, *fakeplatform.FakePlatform) {
	compressor := fakedisk.NewFakeCompressor()
	blobstore := &fakeblobstore.FakeBlobstore{}
	platform := fakeplatform.NewFakePlatform()
	action := newCompilePackage(compressor, blobstore, platform)
	return compressor, blobstore, action, platform.Fs, platform
}
