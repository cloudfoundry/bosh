package blobstore

import (
	boshassert "bosh/assert"
	boshsettings "bosh/settings"
	fakesys "bosh/system/fakes"
	fakeuuid "bosh/uuid/fakes"
	"errors"
	"github.com/stretchr/testify/assert"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestSettingTheOptions(t *testing.T) {
	fs, runner, uuidGen := getS3BlobstoreDependencies()

	_, err := newS3Blobstore(fs, runner, uuidGen).ApplyOptions(map[string]string{
		"access_key_id":     "some-access-key",
		"secret_access_key": "some-secret-key",
		"bucket_name":       "some-bucket",
	})
	assert.NoError(t, err)

	s3CliConfig, err := fs.ReadFile(expectedConfigPath())
	assert.NoError(t, err)

	expectedJson := map[string]string{
		"AccessKey": "some-access-key",
		"SecretKey": "some-secret-key",
		"Bucket":    "some-bucket",
	}
	boshassert.MatchesJsonString(t, expectedJson, s3CliConfig)
}

func TestGet(t *testing.T) {
	fs, runner, uuidGen := getS3BlobstoreDependencies()
	blobstore := newS3Blobstore(fs, runner, uuidGen)

	tempFile, err := fs.TempFile()
	assert.NoError(t, err)

	fs.ReturnTempFile = tempFile
	defer fs.RemoveAll(tempFile.Name())

	file, err := blobstore.Get("fake-blob-id")
	assert.NoError(t, err)

	// downloads correct blob
	assert.Equal(t, 1, len(runner.RunCommands))
	assert.Equal(t, []string{
		"s3", "-c", expectedConfigPath(), "get",
		"fake-blob-id",
		tempFile.Name(),
	}, runner.RunCommands[0])

	// keeps the file
	assert.Equal(t, file, tempFile)
	assert.True(t, fs.FileExists(tempFile.Name()))
}

func TestGetErrsWhenTempFileCreateErrs(t *testing.T) {
	fs, runner, uuidGen := getS3BlobstoreDependencies()
	blobstore := newS3Blobstore(fs, runner, uuidGen)

	fs.TempFileError = errors.New("fake-error")

	file, err := blobstore.Get("fake-blob-id")
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "fake-error")

	assert.Nil(t, file)
}

func TestGetErrsWhenS3CliErrs(t *testing.T) {
	fs, runner, uuidGen := getS3BlobstoreDependencies()
	blobstore := newS3Blobstore(fs, runner, uuidGen)

	tempFile, err := fs.TempFile()
	assert.NoError(t, err)

	fs.ReturnTempFile = tempFile
	defer fs.RemoveAll(tempFile.Name())

	expectedCmd := []string{
		"s3", "-c", expectedConfigPath(), "get",
		"fake-blob-id",
		tempFile.Name(),
	}
	runner.AddCmdResult(strings.Join(expectedCmd, " "), []string{"", "fake-error"})

	file, err := blobstore.Get("fake-blob-id")
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "fake-error")

	// cleans up temporary file
	assert.Nil(t, file)
	assert.False(t, fs.FileExists(tempFile.Name()))
}

func TestCleanUp(t *testing.T) {
	fs, runner, uuidGen := getS3BlobstoreDependencies()
	blobstore := newS3Blobstore(fs, runner, uuidGen)

	file, err := fs.TempFile()
	assert.NoError(t, err)

	defer fs.RemoveAll(file.Name())

	err = blobstore.CleanUp(file)
	assert.NoError(t, err)
	assert.False(t, fs.FileExists(file.Name()))
}

func TestCreate(t *testing.T) {
	file, _ := os.Open("../../../fixtures/some.config")
	expectedPath, _ := filepath.Abs(file.Name())

	fs, runner, uuidGen := getS3BlobstoreDependencies()
	blobstore := newS3Blobstore(fs, runner, uuidGen)

	uuidGen.GeneratedUuid = "some-uuid"

	blobId, err := blobstore.Create(file)
	assert.NoError(t, err)
	assert.Equal(t, blobId, "some-uuid")

	assert.Equal(t, 1, len(runner.RunCommands))
	assert.Equal(t, []string{
		"s3", "-c", expectedConfigPath(), "put",
		expectedPath, "some-uuid",
	}, runner.RunCommands[0])
}

func getS3BlobstoreDependencies() (fs *fakesys.FakeFileSystem, runner *fakesys.FakeCmdRunner, uuidGen *fakeuuid.FakeGenerator) {
	fs = &fakesys.FakeFileSystem{}
	runner = &fakesys.FakeCmdRunner{}
	uuidGen = &fakeuuid.FakeGenerator{}
	return
}

func expectedConfigPath() string {
	return filepath.Join(boshsettings.VCAP_BASE_DIR, "etc", "s3cli")
}
