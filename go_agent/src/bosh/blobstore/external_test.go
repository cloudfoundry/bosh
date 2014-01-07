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

func TestExternalValidateWritesConfigFile(t *testing.T) {
	fs, runner, uuidGen, configPath := getExternalBlobstoreDependencies()

	options := map[string]string{"fake-key": "fake-value"}

	blobstore := newExternalBlobstore("fake-provider", options, fs, runner, uuidGen, configPath)

	runner.CommandExistsValue = true
	assert.NoError(t, blobstore.Validate())

	s3CliConfig, err := fs.ReadFile(configPath)
	assert.NoError(t, err)

	expectedJson := map[string]string{"fake-key": "fake-value"}
	boshassert.MatchesJsonString(t, expectedJson, s3CliConfig)
}

func TestExternalValidateErrorsWhenCommandNotInPath(t *testing.T) {
	fs, runner, uuidGen, configPath := getExternalBlobstoreDependencies()

	options := map[string]string{}

	blobstore := newExternalBlobstore("fake-provider", options, fs, runner, uuidGen, configPath)

	assert.Error(t, blobstore.Validate())
}

func TestExternalGet(t *testing.T) {
	fs, runner, uuidGen, configPath := getExternalBlobstoreDependencies()
	blobstore := newExternalBlobstore("fake-provider", map[string]string{}, fs, runner, uuidGen, configPath)

	tempFile, err := fs.TempFile("bosh-blobstore-external-TestGet")
	assert.NoError(t, err)

	fs.ReturnTempFile = tempFile
	defer fs.RemoveAll(tempFile.Name())

	fileName, err := blobstore.Get("fake-blob-id", "")
	assert.NoError(t, err)

	// downloads correct blob
	assert.Equal(t, 1, len(runner.RunCommands))
	assert.Equal(t, []string{
		"bosh-blobstore-fake-provider", "-c", configPath, "get",
		"fake-blob-id",
		tempFile.Name(),
	}, runner.RunCommands[0])

	// keeps the file
	assert.Equal(t, fileName, tempFile.Name())
	assert.True(t, fs.FileExists(tempFile.Name()))
}

func TestExternalGetErrsWhenTempFileCreateErrs(t *testing.T) {
	fs, runner, uuidGen, configPath := getExternalBlobstoreDependencies()
	blobstore := newExternalBlobstore("fake-provider", map[string]string{}, fs, runner, uuidGen, configPath)

	fs.TempFileError = errors.New("fake-error")

	fileName, err := blobstore.Get("fake-blob-id", "")
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "fake-error")

	assert.Empty(t, fileName)
}

func TestExternalGetErrsWhenExternalCliErrs(t *testing.T) {
	fs, runner, uuidGen, configPath := getExternalBlobstoreDependencies()
	blobstore := newExternalBlobstore("fake-provider", map[string]string{}, fs, runner, uuidGen, configPath)

	tempFile, err := fs.TempFile("bosh-blobstore-external-TestGetErrsWhenExternalCliErrs")
	assert.NoError(t, err)

	fs.ReturnTempFile = tempFile
	defer fs.RemoveAll(tempFile.Name())

	expectedCmd := []string{
		"bosh-blobstore-fake-provider", "-c", configPath, "get",
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

func TestExternalCleanUp(t *testing.T) {
	fs, runner, uuidGen, configPath := getExternalBlobstoreDependencies()
	blobstore := newExternalBlobstore("fake-provider", map[string]string{}, fs, runner, uuidGen, configPath)

	file, err := fs.TempFile("bosh-blobstore-external-TestCleanUp")
	assert.NoError(t, err)
	fileName := file.Name()

	defer fs.RemoveAll(fileName)

	err = blobstore.CleanUp(fileName)
	assert.NoError(t, err)
	assert.False(t, fs.FileExists(fileName))
}

func TestExternalCreate(t *testing.T) {
	fileName := "../../../fixtures/some.config"
	expectedPath, _ := filepath.Abs(fileName)

	fs, runner, uuidGen, configPath := getExternalBlobstoreDependencies()
	blobstore := newExternalBlobstore("fake-provider", map[string]string{}, fs, runner, uuidGen, configPath)

	uuidGen.GeneratedUuid = "some-uuid"

	blobId, fingerprint, err := blobstore.Create(fileName)
	assert.NoError(t, err)
	assert.Equal(t, blobId, "some-uuid")
	assert.Empty(t, fingerprint)

	assert.Equal(t, 1, len(runner.RunCommands))
	assert.Equal(t, []string{
		"bosh-blobstore-fake-provider", "-c", configPath, "put",
		expectedPath, "some-uuid",
	}, runner.RunCommands[0])
}

func getExternalBlobstoreDependencies() (fs *fakesys.FakeFileSystem, runner *fakesys.FakeCmdRunner, uuidGen *fakeuuid.FakeGenerator, configPath string) {
	fs = &fakesys.FakeFileSystem{}
	runner = &fakesys.FakeCmdRunner{}
	uuidGen = &fakeuuid.FakeGenerator{}
	dirProvider := boshdir.NewDirectoriesProvider("/var/vcap")
	configPath = filepath.Join(dirProvider.EtcDir(), "blobstore-fake-provider.json")
	return
}
