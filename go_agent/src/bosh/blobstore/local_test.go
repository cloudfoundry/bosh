package blobstore

import (
	fakesys "bosh/system/fakes"
	fakeuuid "bosh/uuid/fakes"
	"errors"
	. "github.com/onsi/ginkgo"
	"github.com/stretchr/testify/assert"
)

const FAKE_BLOBSTORE_PATH = "/some/local/path"

func buildLocalBlobstore() (fs *fakesys.FakeFileSystem, uuidGen *fakeuuid.FakeGenerator, blobstore local) {
	fs = &fakesys.FakeFileSystem{}
	uuidGen = &fakeuuid.FakeGenerator{}
	options := map[string]string{
		"blobstore_path": FAKE_BLOBSTORE_PATH,
	}

	blobstore = newLocalBlobstore(options, fs, uuidGen)
	return
}
func init() {
	Describe("Testing with Ginkgo", func() {
		It("local validate", func() {
			_, _, blobstore := buildLocalBlobstore()

			err := blobstore.Validate()
			assert.NoError(GinkgoT(), err)
		})
		It("local validate errs when missing blobstore path", func() {

			_, _, blobstore := buildLocalBlobstore()
			blobstore.options = map[string]string{}

			err := blobstore.Validate()
			assert.Error(GinkgoT(), err)
			assert.Contains(GinkgoT(), err.Error(), "missing blobstore_path")
		})
		It("local get", func() {

			fs, _, blobstore := buildLocalBlobstore()

			fs.WriteToFile(FAKE_BLOBSTORE_PATH+"/fake-blob-id", "fake contents")

			tempFile, err := fs.TempFile("bosh-blobstore-local-TestLocalGet")
			assert.NoError(GinkgoT(), err)

			fs.ReturnTempFile = tempFile
			defer fs.RemoveAll(tempFile.Name())

			_, err = blobstore.Get("fake-blob-id", "")
			assert.NoError(GinkgoT(), err)

			fileStats := fs.GetFileTestStat(tempFile.Name())
			assert.NotNil(GinkgoT(), fileStats)
			assert.Equal(GinkgoT(), "fake contents", fileStats.Content)
		})
		It("local get errs when temp file create errs", func() {

			fs, _, blobstore := buildLocalBlobstore()

			fs.TempFileError = errors.New("fake-error")

			fileName, err := blobstore.Get("fake-blob-id", "")
			assert.Error(GinkgoT(), err)
			assert.Contains(GinkgoT(), err.Error(), "fake-error")

			assert.Empty(GinkgoT(), fileName)
		})
		It("local get errs when copy file errs", func() {

			fs, _, blobstore := buildLocalBlobstore()

			tempFile, err := fs.TempFile("bosh-blobstore-local-TestLocalGetErrsWhenCopyFileErrs")
			assert.NoError(GinkgoT(), err)

			fs.ReturnTempFile = tempFile
			defer fs.RemoveAll(tempFile.Name())

			fs.CopyFileError = errors.New("fake-copy-file-error")

			fileName, err := blobstore.Get("fake-blob-id", "")
			assert.Error(GinkgoT(), err)
			assert.Contains(GinkgoT(), err.Error(), "fake-copy-file-error")

			assert.Empty(GinkgoT(), fileName)
			assert.False(GinkgoT(), fs.FileExists(tempFile.Name()))
		})
		It("local clean up", func() {

			fs, _, blobstore := buildLocalBlobstore()

			file, err := fs.TempFile("bosh-blobstore-local-TestLocalCleanUp")
			assert.NoError(GinkgoT(), err)
			fileName := file.Name()

			defer fs.RemoveAll(fileName)

			err = blobstore.CleanUp(fileName)
			assert.NoError(GinkgoT(), err)
			assert.False(GinkgoT(), fs.FileExists(fileName))
		})
		It("local create", func() {

			fs, uuidGen, blobstore := buildLocalBlobstore()
			fs.WriteToFile("/fake-file.txt", "fake-file-contents")

			uuidGen.GeneratedUuid = "some-uuid"

			blobId, fingerprint, err := blobstore.Create("/fake-file.txt")
			assert.NoError(GinkgoT(), err)
			assert.Equal(GinkgoT(), blobId, "some-uuid")
			assert.Empty(GinkgoT(), fingerprint)

			writtenFileStats := fs.GetFileTestStat(FAKE_BLOBSTORE_PATH + "/some-uuid")
			assert.NotNil(GinkgoT(), writtenFileStats)
			assert.Equal(GinkgoT(), "fake-file-contents", writtenFileStats.Content)
		})
		It("local create errs when generating blob id errs", func() {

			_, uuidGen, blobstore := buildLocalBlobstore()

			uuidGen.GenerateError = errors.New("some-unfortunate-error")

			_, _, err := blobstore.Create("some/file")
			assert.Error(GinkgoT(), err)
			assert.Contains(GinkgoT(), err.Error(), "some-unfortunate-error")
		})
		It("local create errs when copy file errs", func() {

			fs, uuidGen, blobstore := buildLocalBlobstore()
			fs.WriteToFile("/fake-file.txt", "fake-file-contents")

			uuidGen.GeneratedUuid = "some-uuid"
			fs.CopyFileError = errors.New("fake-copy-file-error")

			_, _, err := blobstore.Create("/fake-file.txt")
			assert.Error(GinkgoT(), err)
			assert.Contains(GinkgoT(), err.Error(), "fake-copy-file-error")
		})
	})
}
