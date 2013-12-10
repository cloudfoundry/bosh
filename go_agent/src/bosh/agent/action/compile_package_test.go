package action

import (
	fakeblobstore "bosh/blobstore/fakes"
	fakedisk "bosh/platform/disk/fakes"
	fakesys "bosh/system/fakes"
	"github.com/stretchr/testify/assert"
	"os"
	"testing"
)

func TestCompilePackageShouldBeAsynchronous(t *testing.T) {
	_, _, action, _ := buildCompilePackageAction()
	assert.True(t, action.IsAsynchronous())
}

func TestCompilePackageFetchesSourcePackageFromBlobstore(t *testing.T) {
	_, blobstore, action, _ := buildCompilePackageAction()

	payload := getTestPayload()

	_, err := action.Run([]byte(payload))
	assert.NoError(t, err)

	assert.Equal(t, "first_dep_blobstore_id", blobstore.GetBlobIds[0])
	assert.Equal(t, "sec_dep_blobstore_id", blobstore.GetBlobIds[1])
	assert.Equal(t, "blobstore_id", blobstore.GetBlobIds[2])
}

func TestCompilePackageExtractsDependenciesToPackagesDir(t *testing.T) {
	compressor, blobstore, action, _ := buildCompilePackageAction()

	payload := getTestPayload()

	file, err := os.Open("/dev/null")
	assert.NoError(t, err)
	defer file.Close()

	blobstore.GetFile = file

	_, err = action.Run([]byte(payload))
	assert.NoError(t, err)

	assert.Equal(t, compressor.DecompressFileToDirDirs[0], "/var/vcap/data/packages/first_dep/first_dep_version")
	assert.Equal(t, compressor.DecompressFileToDirDirs[1], "/var/vcap/data/packages/sec_dep/sec_dep_version")

	assert.Equal(t, compressor.DecompressFileToDirTarballs[0], file)
	assert.Equal(t, compressor.DecompressFileToDirTarballs[1], file)
}

func TestCompilePackageExtractsSourcePkgToCompileDir(t *testing.T) {
	compressor, blobstore, action, fs := buildCompilePackageAction()

	payload := getTestPayload()

	file, err := os.Open("/dev/null")
	assert.NoError(t, err)
	defer file.Close()

	blobstore.GetFile = file

	_, err = action.Run([]byte(payload))
	assert.NoError(t, err)

	assert.True(t, fs.FileExists("/var/vcap/data/compile/pkg_name"))
	assert.Equal(t, compressor.DecompressFileToDirDirs[2], "/var/vcap/data/compile/pkg_name")
	assert.Equal(t, compressor.DecompressFileToDirTarballs[2], file)
}

func getTestPayload() (payload string) {
	payload = `
		{
			"arguments": [
				"blobstore_id",
				"sha1",
				"pkg_name",
				"pkg_version",
				{
					"first_dep": {
						"blobstore_id": "first_dep_blobstore_id",
						"name": "first_dep",
						"sha1": "first_dep_sha1",
						"version": "first_dep_version"
					},
					"sec_dep": {
						"blobstore_id": "sec_dep_blobstore_id",
						"name": "sec_dep",
						"sha1": "sec_dep_sha1",
						"version": "sec_dep_version"
					}
				}
			]
		}
		`
	return
}

func buildCompilePackageAction() (*fakedisk.FakeCompressor, *fakeblobstore.FakeBlobstore, compilePackageAction, *fakesys.FakeFileSystem) {
	compressor := fakedisk.NewFakeCompressor()
	blobstore := &fakeblobstore.FakeBlobstore{}
	fakeFs := fakesys.NewFakeFileSystem()
	action := newCompilePackage(compressor, blobstore, fakeFs)
	return compressor, blobstore, action, fakeFs
}
