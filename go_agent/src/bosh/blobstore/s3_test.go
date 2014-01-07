package blobstore

import (
	boshassert "bosh/assert"
	boshdir "bosh/settings/directories"
	fakesys "bosh/system/fakes"
	fakeuuid "bosh/uuid/fakes"
	"errors"
	"github.com/stretchr/testify/assert"
	"path/filepath"
	"strings"
	"testing"
)

func TestS3ValidateWritesConfigFile(t *testing.T) {
	fs, runner, uuidGen, configPath := getS3BlobstoreDependencies()

	options := map[string]string{
		"access_key_id":     "some-access-key",
		"secret_access_key": "some-secret-key",
		"bucket_name":       "some-bucket",
	}

	blobstore := newS3Blobstore(options, fs, runner, uuidGen, configPath)

	runner.CommandExistsValue = true
	assert.NoError(t, blobstore.Validate())

	s3CliConfig, err := fs.ReadFile(configPath)
	assert.NoError(t, err)

	expectedJson := map[string]string{
		"AccessKey": "some-access-key",
		"SecretKey": "some-secret-key",
		"Bucket":    "some-bucket",
	}
	boshassert.MatchesJsonString(t, expectedJson, s3CliConfig)
}

func TestS3ValidateErrorsWhenCommandNotInPath(t *testing.T) {
	fs, runner, uuidGen, configPath := getS3BlobstoreDependencies()

	options := map[string]string{}

	blobstore := newS3Blobstore(options, fs, runner, uuidGen, configPath)

	assert.Error(t, blobstore.Validate())
}

func TestGet(t *testing.T) {
	fs, runner, uuidGen, configPath := getS3BlobstoreDependencies()
	blobstore := newS3Blobstore(map[string]string{}, fs, runner, uuidGen, configPath)

	tempFile, err := fs.TempFile("bosh-blobstore-s3-TestGet")
	assert.NoError(t, err)

	fs.ReturnTempFile = tempFile
	defer fs.RemoveAll(tempFile.Name())

	fileName, err := blobstore.Get("fake-blob-id", "")
	assert.NoError(t, err)

	// downloads correct blob
	assert.Equal(t, 1, len(runner.RunCommands))
	assert.Equal(t, []string{
		"s3", "-c", configPath, "get",
		"fake-blob-id",
		tempFile.Name(),
	}, runner.RunCommands[0])

	// keeps the file
	assert.Equal(t, fileName, tempFile.Name())
	assert.True(t, fs.FileExists(tempFile.Name()))
}

func TestGetErrsWhenTempFileCreateErrs(t *testing.T) {
	fs, runner, uuidGen, configPath := getS3BlobstoreDependencies()
	blobstore := newS3Blobstore(map[string]string{}, fs, runner, uuidGen, configPath)

	fs.TempFileError = errors.New("fake-error")

	fileName, err := blobstore.Get("fake-blob-id", "")
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "fake-error")

	assert.Empty(t, fileName)
}

func TestGetErrsWhenS3CliErrs(t *testing.T) {
	fs, runner, uuidGen, configPath := getS3BlobstoreDependencies()
	blobstore := newS3Blobstore(map[string]string{}, fs, runner, uuidGen, configPath)

	tempFile, err := fs.TempFile("bosh-blobstore-s3-TestGetErrsWhenS3CliErrs")
	assert.NoError(t, err)

	fs.ReturnTempFile = tempFile
	defer fs.RemoveAll(tempFile.Name())

	expectedCmd := []string{
		"s3", "-c", configPath, "get",
		"fake-blob-id",
		tempFile.Name(),
	}
	runner.AddCmdResult(strings.Join(expectedCmd, " "), fakesys.FakeCmdResult{Error: errors.New("fake-error")})

	fileName, err := blobstore.Get("fake-blob-id", "")
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "fake-error")

	// cleans up temporary file
	assert.Empty(t, fileName)
	assert.False(t, fs.FileExists(tempFile.Name()))
}

func TestCleanUp(t *testing.T) {
	fs, runner, uuidGen, configPath := getS3BlobstoreDependencies()
	blobstore := newS3Blobstore(map[string]string{}, fs, runner, uuidGen, configPath)

	file, err := fs.TempFile("bosh-blobstore-s3-TestCleanUp")
	assert.NoError(t, err)
	fileName := file.Name()

	defer fs.RemoveAll(fileName)

	err = blobstore.CleanUp(fileName)
	assert.NoError(t, err)
	assert.False(t, fs.FileExists(fileName))
}

func TestCreate(t *testing.T) {
	fileName := "../../../fixtures/some.config"
	expectedPath, _ := filepath.Abs(fileName)

	fs, runner, uuidGen, configPath := getS3BlobstoreDependencies()
	blobstore := newS3Blobstore(map[string]string{}, fs, runner, uuidGen, configPath)

	uuidGen.GeneratedUuid = "some-uuid"

	blobId, fingerprint, err := blobstore.Create(fileName)
	assert.NoError(t, err)
	assert.Equal(t, blobId, "some-uuid")
	assert.Empty(t, fingerprint)

	assert.Equal(t, 1, len(runner.RunCommands))
	assert.Equal(t, []string{
		"s3", "-c", configPath, "put",
		expectedPath, "some-uuid",
	}, runner.RunCommands[0])
}

func getS3BlobstoreDependencies() (fs *fakesys.FakeFileSystem, runner *fakesys.FakeCmdRunner, uuidGen *fakeuuid.FakeGenerator, configPath string) {
	fs = &fakesys.FakeFileSystem{}
	runner = &fakesys.FakeCmdRunner{}
	uuidGen = &fakeuuid.FakeGenerator{}
	dirProvider := boshdir.NewDirectoriesProvider("/var/vcap")
	configPath = filepath.Join(dirProvider.EtcDir(), "s3cli")
	return
}
