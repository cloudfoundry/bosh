package blobstore_test

import (
	"errors"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	. "bosh/blobstore"
	fakesys "bosh/system/fakes"
	fakeuuid "bosh/uuid/fakes"
)

var _ = Describe("localBlobstore", func() {
	var (
		fs                *fakesys.FakeFileSystem
		uuidGen           *fakeuuid.FakeGenerator
		fakeBlobstorePath = "/some/local/path"
		blobstore         Blobstore
	)

	BeforeEach(func() {
		fs = fakesys.NewFakeFileSystem()
		uuidGen = &fakeuuid.FakeGenerator{}
		options := map[string]interface{}{"blobstore_path": fakeBlobstorePath}
		blobstore = NewLocalBlobstore(fs, uuidGen, options)
	})

	Describe("Validate", func() {
		It("returns no error when blobstore_path is present", func() {
			err := blobstore.Validate()
			Expect(err).ToNot(HaveOccurred())
		})

		It("returns error when missing blobstore path", func() {
			options := map[string]interface{}{}
			blobstore = NewLocalBlobstore(fs, uuidGen, options)

			err := blobstore.Validate()
			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(ContainSubstring("missing blobstore_path"))
		})

		It("returns error when blobstore path is not a string", func() {
			options := map[string]interface{}{"blobstore_path": 443}
			blobstore = NewLocalBlobstore(fs, uuidGen, options)

			err := blobstore.Validate()
			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(ContainSubstring("blobstore_path must be a string"))
		})
	})

	Describe("Get", func() {
		It("local get", func() {
			fs.WriteFileString(fakeBlobstorePath+"/fake-blob-id", "fake contents")

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
			fs.TempFileError = errors.New("fake-error")

			fileName, err := blobstore.Get("fake-blob-id", "")
			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(ContainSubstring("fake-error"))

			Expect(fileName).To(BeEmpty())
		})

		It("local get errs when copy file errs", func() {
			tempFile, err := fs.TempFile("bosh-blobstore-local-TestLocalGetErrsWhenCopyFileErrs")
			Expect(err).ToNot(HaveOccurred())

			fs.ReturnTempFile = tempFile
			defer fs.RemoveAll(tempFile.Name())

			fs.CopyFileError = errors.New("fake-copy-file-error")

			fileName, err := blobstore.Get("fake-blob-id", "")
			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(ContainSubstring("fake-copy-file-error"))

			Expect(fileName).To(BeEmpty())
			Expect(fs.FileExists(tempFile.Name())).To(BeFalse())
		})
	})

	Describe("CleanUp", func() {
		It("local clean up", func() {
			file, err := fs.TempFile("bosh-blobstore-local-TestLocalCleanUp")
			Expect(err).ToNot(HaveOccurred())
			fileName := file.Name()

			defer fs.RemoveAll(fileName)

			err = blobstore.CleanUp(fileName)
			Expect(err).ToNot(HaveOccurred())
			Expect(fs.FileExists(fileName)).To(BeFalse())
		})
	})

	Describe("Create", func() {
		It("local create", func() {
			fs.WriteFileString("/fake-file.txt", "fake-file-contents")

			uuidGen.GeneratedUuid = "some-uuid"

			blobID, fingerprint, err := blobstore.Create("/fake-file.txt")
			Expect(err).ToNot(HaveOccurred())
			Expect(blobID).To(Equal("some-uuid"))
			Expect(fingerprint).To(BeEmpty())

			writtenFileStats := fs.GetFileTestStat(fakeBlobstorePath + "/some-uuid")
			Expect(writtenFileStats).ToNot(BeNil())
			Expect("fake-file-contents").To(Equal(writtenFileStats.StringContents()))
		})

		It("local create errs when generating blob id errs", func() {
			uuidGen.GenerateError = errors.New("some-unfortunate-error")

			_, _, err := blobstore.Create("some/file")
			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(ContainSubstring("some-unfortunate-error"))
		})

		It("local create errs when copy file errs", func() {
			fs.WriteFileString("/fake-file.txt", "fake-file-contents")

			uuidGen.GeneratedUuid = "some-uuid"
			fs.CopyFileError = errors.New("fake-copy-file-error")

			_, _, err := blobstore.Create("/fake-file.txt")
			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(ContainSubstring("fake-copy-file-error"))
		})
	})

})
