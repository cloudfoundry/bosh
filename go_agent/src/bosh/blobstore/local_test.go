package blobstore

import (
	"errors"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
	"github.com/stretchr/testify/assert"

	fakesys "bosh/system/fakes"
	fakeuuid "bosh/uuid/fakes"
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
			Expect(err).ToNot(HaveOccurred())
		})
		It("local validate errs when missing blobstore path", func() {

			_, _, blobstore := buildLocalBlobstore()
			blobstore.options = map[string]string{}

			err := blobstore.Validate()
			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(ContainSubstring("missing blobstore_path"))
		})
		It("local get", func() {

			fs, _, blobstore := buildLocalBlobstore()

			fs.WriteFileString(FAKE_BLOBSTORE_PATH+"/fake-blob-id", "fake contents")

			tempFile, err := fs.TempFile("bosh-blobstore-local-TestLocalGet")
			Expect(err).ToNot(HaveOccurred())

			fs.ReturnTempFile = tempFile
			defer fs.RemoveAll(tempFile.Name())

			_, err = blobstore.Get("fake-blob-id", "")
			Expect(err).ToNot(HaveOccurred())

			fileStats := fs.GetFileTestStat(tempFile.Name())
			Expect(fileStats).ToNot(BeNil())
			Expect("fake contents").To(Equal(fileStats.StringContents()))
		})
		It("local get errs when temp file create errs", func() {

			fs, _, blobstore := buildLocalBlobstore()

			fs.TempFileError = errors.New("fake-error")

			fileName, err := blobstore.Get("fake-blob-id", "")
			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(ContainSubstring("fake-error"))

			assert.Empty(GinkgoT(), fileName)
		})
		It("local get errs when copy file errs", func() {

			fs, _, blobstore := buildLocalBlobstore()

			tempFile, err := fs.TempFile("bosh-blobstore-local-TestLocalGetErrsWhenCopyFileErrs")
			Expect(err).ToNot(HaveOccurred())

			fs.ReturnTempFile = tempFile
			defer fs.RemoveAll(tempFile.Name())

			fs.CopyFileError = errors.New("fake-copy-file-error")

			fileName, err := blobstore.Get("fake-blob-id", "")
			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(ContainSubstring("fake-copy-file-error"))

			assert.Empty(GinkgoT(), fileName)
			Expect(fs.FileExists(tempFile.Name())).To(BeFalse())
		})
		It("local clean up", func() {

			fs, _, blobstore := buildLocalBlobstore()

			file, err := fs.TempFile("bosh-blobstore-local-TestLocalCleanUp")
			Expect(err).ToNot(HaveOccurred())
			fileName := file.Name()

			defer fs.RemoveAll(fileName)

			err = blobstore.CleanUp(fileName)
			Expect(err).ToNot(HaveOccurred())
			Expect(fs.FileExists(fileName)).To(BeFalse())
		})
		It("local create", func() {

			fs, uuidGen, blobstore := buildLocalBlobstore()
			fs.WriteFileString("/fake-file.txt", "fake-file-contents")

			uuidGen.GeneratedUuid = "some-uuid"

			blobId, fingerprint, err := blobstore.Create("/fake-file.txt")
			Expect(err).ToNot(HaveOccurred())
			Expect(blobId).To(Equal("some-uuid"))
			assert.Empty(GinkgoT(), fingerprint)

			writtenFileStats := fs.GetFileTestStat(FAKE_BLOBSTORE_PATH + "/some-uuid")
			Expect(writtenFileStats).ToNot(BeNil())
			Expect("fake-file-contents").To(Equal(writtenFileStats.StringContents()))
		})
		It("local create errs when generating blob id errs", func() {

			_, uuidGen, blobstore := buildLocalBlobstore()

			uuidGen.GenerateError = errors.New("some-unfortunate-error")

			_, _, err := blobstore.Create("some/file")
			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(ContainSubstring("some-unfortunate-error"))
		})
		It("local create errs when copy file errs", func() {

			fs, uuidGen, blobstore := buildLocalBlobstore()
			fs.WriteFileString("/fake-file.txt", "fake-file-contents")

			uuidGen.GeneratedUuid = "some-uuid"
			fs.CopyFileError = errors.New("fake-copy-file-error")

			_, _, err := blobstore.Create("/fake-file.txt")
			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(ContainSubstring("fake-copy-file-error"))
		})
	})
}
