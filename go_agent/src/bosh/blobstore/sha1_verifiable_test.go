package blobstore_test

import (
	"errors"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	boshblob "bosh/blobstore"
	fakeblob "bosh/blobstore/fakes"
	bosherr "bosh/errors"
)

func buildSha1Verifiable() (innerBlobstore *fakeblob.FakeBlobstore, sha1Verifiable boshblob.Blobstore) {
	innerBlobstore = &fakeblob.FakeBlobstore{}
	sha1Verifiable = boshblob.NewSha1Verifiable(innerBlobstore)
	return
}

func init() {
	Describe("Testing with Ginkgo", func() {
		It("sha1 verifiable validate", func() {
			innerBlobstore, sha1Verifiable := buildSha1Verifiable()

			err := sha1Verifiable.Validate()
			Expect(err).ToNot(HaveOccurred())

			innerBlobstore.ValidateError = bosherr.New("fake-validate-error")

			err = sha1Verifiable.Validate()
			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(ContainSubstring("fake-validate-error"))
		})

		It("sha1 verifiable get when sha1 is correct", func() {
			innerBlobstore, sha1Verifiable := buildSha1Verifiable()

			innerBlobstore.GetFileName = "../../../fixtures/some.config"
			validSha1 := "da39a3ee5e6b4b0d3255bfef95601890afd80709"

			fileName, err := sha1Verifiable.Get("some-blob-id", validSha1)
			Expect(err).ToNot(HaveOccurred())

			Expect(innerBlobstore.GetFileName).To(Equal(fileName))
		})

		It("sha1 verifiable get when sha1 is incorrect", func() {
			innerBlobstore, sha1Verifiable := buildSha1Verifiable()

			innerBlobstore.GetFileName = "../../../fixtures/some.config"
			incorrectSha1 := "some-incorrect-sha1"

			_, err := sha1Verifiable.Get("some-blob-id", incorrectSha1)
			Expect(err).To(HaveOccurred())
		})

		It("sha1 verifiable errs when get errs", func() {
			innerBlobstore, sha1Verifiable := buildSha1Verifiable()
			innerBlobstore.GetError = errors.New("fake-get-error")
			validSha1 := "da39a3ee5e6b4b0d3255bfef95601890afd80709"

			_, err := sha1Verifiable.Get("some-blob-id", validSha1)
			Expect(err.Error()).To(ContainSubstring("fake-get-error"))
		})

		It("sha1 verifiable skips testings if sha1 is empty", func() {
			innerBlobstore, sha1Verifiable := buildSha1Verifiable()

			innerBlobstore.GetFileName = "../../../fixtures/some.config"
			emptySha1 := ""

			fileName, err := sha1Verifiable.Get("some-blob-id", emptySha1)
			Expect(err).ToNot(HaveOccurred())

			Expect(innerBlobstore.GetFileName).To(Equal(fileName))
		})

		It("sha1 verifiable cleanup", func() {
			innerBlobstore, sha1Verifiable := buildSha1Verifiable()
			innerBlobstore.CleanUpErr = errors.New("fake-clean-up-error")

			err := sha1Verifiable.CleanUp("/some/file")
			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(ContainSubstring("fake-clean-up-error"))

			Expect(innerBlobstore.CleanUpFileName).To(Equal("/some/file"))
		})

		It("sha1 verifiable create", func() {
			innerBlobstore, sha1Verifiable := buildSha1Verifiable()
			innerBlobstore.CreateErr = errors.New("fake-create-error")
			innerBlobstore.CreateBlobID = "blob-id"

			expectedSha1 := "da39a3ee5e6b4b0d3255bfef95601890afd80709"

			blobID, sha1, err := sha1Verifiable.Create("../../../fixtures/some.config")
			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(ContainSubstring("fake-create-error"))
			Expect(blobID).To(Equal("blob-id"))
			Expect(sha1).To(Equal(expectedSha1))

			Expect(innerBlobstore.CreateFileName).To(Equal("../../../fixtures/some.config"))
		})
	})
}
