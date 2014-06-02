package blobstore_test

import (
	"errors"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	boshblob "bosh/blobstore"
	fakeblob "bosh/blobstore/fakes"
	bosherr "bosh/errors"
)

var _ = Describe("sha1VerifiableBlobstore", func() {
	const (
		fixturePath = "../../../fixtures/some.config"
		fixtureSHA1 = "da39a3ee5e6b4b0d3255bfef95601890afd80709"
	)

	var (
		innerBlobstore          *fakeblob.FakeBlobstore
		sha1VerifiableBlobstore boshblob.Blobstore
	)

	BeforeEach(func() {
		innerBlobstore = &fakeblob.FakeBlobstore{}
		sha1VerifiableBlobstore = boshblob.NewSHA1VerifiableBlobstore(innerBlobstore)
	})

	Describe("Get", func() {
		It("returns without an error if sha1 matches", func() {
			innerBlobstore.GetFileName = fixturePath

			fileName, err := sha1VerifiableBlobstore.Get("fake-blob-id", fixtureSHA1)
			Expect(err).ToNot(HaveOccurred())

			Expect(innerBlobstore.GetBlobIDs).To(Equal([]string{"fake-blob-id"}))
			Expect(fileName).To(Equal(fixturePath))
		})

		It("returns error if sha1 does not match", func() {
			innerBlobstore.GetFileName = fixturePath
			incorrectSha1 := "some-incorrect-sha1"

			_, err := sha1VerifiableBlobstore.Get("fake-blob-id", incorrectSha1)
			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(ContainSubstring("SHA1 mismatch"))
		})

		It("returns error if inner blobstore getting fails", func() {
			innerBlobstore.GetError = errors.New("fake-get-error")

			_, err := sha1VerifiableBlobstore.Get("fake-blob-id", fixtureSHA1)
			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(ContainSubstring("fake-get-error"))
		})

		It("skips sha1 verification and returns without an error if sha1 is empty", func() {
			innerBlobstore.GetFileName = fixturePath

			fileName, err := sha1VerifiableBlobstore.Get("fake-blob-id", "")
			Expect(err).ToNot(HaveOccurred())

			Expect(fileName).To(Equal(fixturePath))
		})
	})

	Describe("CleanUp", func() {
		It("delegates to inner blobstore to clean up", func() {
			err := sha1VerifiableBlobstore.CleanUp("/some/file")
			Expect(err).ToNot(HaveOccurred())

			Expect(innerBlobstore.CleanUpFileName).To(Equal("/some/file"))
		})

		It("returns error if inner blobstore cleaning up fails", func() {
			innerBlobstore.CleanUpErr = errors.New("fake-clean-up-error")

			err := sha1VerifiableBlobstore.CleanUp("/some/file")
			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(ContainSubstring("fake-clean-up-error"))
		})
	})

	Describe("Create", func() {
		It("delegates to inner blobstore to create blob and returns sha1 of returned blob", func() {
			innerBlobstore.CreateBlobID = "fake-blob-id"

			blobID, sha1, err := sha1VerifiableBlobstore.Create(fixturePath)
			Expect(err).ToNot(HaveOccurred())
			Expect(blobID).To(Equal("fake-blob-id"))
			Expect(sha1).To(Equal(fixtureSHA1))

			Expect(innerBlobstore.CreateFileName).To(Equal(fixturePath))
		})

		It("returns error if inner blobstore blob creation fails", func() {
			innerBlobstore.CreateErr = errors.New("fake-create-error")

			_, _, err := sha1VerifiableBlobstore.Create(fixturePath)
			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(ContainSubstring("fake-create-error"))
		})
	})

	Describe("Validate", func() {
		It("delegates to inner blobstore to validate", func() {
			err := sha1VerifiableBlobstore.Validate()
			Expect(err).ToNot(HaveOccurred())
		})

		It("returns error if inner blobstore validation fails", func() {
			innerBlobstore.ValidateError = bosherr.New("fake-validate-error")

			err := sha1VerifiableBlobstore.Validate()
			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(ContainSubstring("fake-validate-error"))
		})
	})
})
