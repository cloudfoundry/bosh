package blobstore

import (
	fakesys "bosh/system/fakes"
	fakeuuid "bosh/uuid/fakes"
	"errors"
	"github.com/stretchr/testify/assert"
	"testing"
)

const FAKE_BLOBSTORE_PATH = "/some/local/path"

func TestLocalValidate(t *testing.T) {
	_, _, blobstore := buildLocalBlobstore()

	err := blobstore.Validate()
	assert.NoError(t, err)
}

func TestLocalValidateErrsWhenMissingBlobstorePath(t *testing.T) {
	_, _, blobstore := buildLocalBlobstore()
	blobstore.options = map[string]string{}

	err := blobstore.Validate()
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "missing blobstore_path")
}

func TestLocalGet(t *testing.T) {
	fs, _, blobstore := buildLocalBlobstore()

	fs.WriteToFile(FAKE_BLOBSTORE_PATH+"/fake-blob-id", "fake contents")

	tempFile, err := fs.TempFile("bosh-blobstore-local-TestLocalGet")
	assert.NoError(t, err)

	fs.ReturnTempFile = tempFile
	defer fs.RemoveAll(tempFile.Name())

	_, err = blobstore.Get("fake-blob-id", "")
	assert.NoError(t, err)

	fileStats := fs.GetFileTestStat(tempFile.Name())
	assert.NotNil(t, fileStats)
	assert.Equal(t, "fake contents", fileStats.Content)
}

func TestLocalGetErrsWhenTempFileCreateErrs(t *testing.T) {
	fs, _, blobstore := buildLocalBlobstore()

	fs.TempFileError = errors.New("fake-error")

	fileName, err := blobstore.Get("fake-blob-id", "")
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "fake-error")

	assert.Empty(t, fileName)
}

func TestLocalGetErrsWhenCopyFileErrs(t *testing.T) {
	fs, _, blobstore := buildLocalBlobstore()

	tempFile, err := fs.TempFile("bosh-blobstore-local-TestLocalGetErrsWhenCopyFileErrs")
	assert.NoError(t, err)

	fs.ReturnTempFile = tempFile
	defer fs.RemoveAll(tempFile.Name())

	fs.CopyFileError = errors.New("fake-copy-file-error")

	fileName, err := blobstore.Get("fake-blob-id", "")
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "fake-copy-file-error")

	// cleans up temporary file
	assert.Empty(t, fileName)
	assert.False(t, fs.FileExists(tempFile.Name()))
}

func TestLocalCleanUp(t *testing.T) {
	fs, _, blobstore := buildLocalBlobstore()

	file, err := fs.TempFile("bosh-blobstore-local-TestLocalCleanUp")
	assert.NoError(t, err)
	fileName := file.Name()

	defer fs.RemoveAll(fileName)

	err = blobstore.CleanUp(fileName)
	assert.NoError(t, err)
	assert.False(t, fs.FileExists(fileName))
}

func TestLocalCreate(t *testing.T) {
	fs, uuidGen, blobstore := buildLocalBlobstore()
	fs.WriteToFile("/fake-file.txt", "fake-file-contents")

	uuidGen.GeneratedUuid = "some-uuid"

	blobId, fingerprint, err := blobstore.Create("/fake-file.txt")
	assert.NoError(t, err)
	assert.Equal(t, blobId, "some-uuid")
	assert.Empty(t, fingerprint)

	writtenFileStats := fs.GetFileTestStat(FAKE_BLOBSTORE_PATH + "/some-uuid")
	assert.NotNil(t, writtenFileStats)
	assert.Equal(t, "fake-file-contents", writtenFileStats.Content)
}

func TestLocalCreateErrsWhenGeneratingBlobIdErrs(t *testing.T) {
	_, uuidGen, blobstore := buildLocalBlobstore()

	uuidGen.GenerateError = errors.New("some-unfortunate-error")

	_, _, err := blobstore.Create("some/file")
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "some-unfortunate-error")
}

func TestLocalCreateErrsWhenCopyFileErrs(t *testing.T) {
	fs, uuidGen, blobstore := buildLocalBlobstore()
	fs.WriteToFile("/fake-file.txt", "fake-file-contents")

	uuidGen.GeneratedUuid = "some-uuid"
	fs.CopyFileError = errors.New("fake-copy-file-error")

	_, _, err := blobstore.Create("/fake-file.txt")
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "fake-copy-file-error")
}

func buildLocalBlobstore() (fs *fakesys.FakeFileSystem, uuidGen *fakeuuid.FakeGenerator, blobstore local) {
	fs = &fakesys.FakeFileSystem{}
	uuidGen = &fakeuuid.FakeGenerator{}
	options := map[string]string{
		"blobstore_path": FAKE_BLOBSTORE_PATH,
	}

	blobstore = newLocalBlobstore(options, fs, uuidGen)
	return
}
