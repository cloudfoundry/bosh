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

			innerBlobstore.ValidateError = bosherr.New("fake-error")
			err = sha1Verifiable.Validate()
			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(ContainSubstring("fake-error"))
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
			innerBlobstore.GetError = errors.New("Error getting blob")
			validSha1 := "da39a3ee5e6b4b0d3255bfef95601890afd80709"

			_, err := sha1Verifiable.Get("some-blob-id", validSha1)
			Expect(err.Error()).To(ContainSubstring(innerBlobstore.GetError.Error()))
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
			innerBlobstore.CleanUpErr = errors.New("Cleanup err")

			err := sha1Verifiable.CleanUp("/some/file")

			Expect(err).To(Equal(innerBlobstore.CleanUpErr))
			Expect("/some/file").To(Equal(innerBlobstore.CleanUpFileName))
		})
		It("sha1 verifiable create", func() {

			innerBlobstore, sha1Verifiable := buildSha1Verifiable()
			innerBlobstore.CreateErr = errors.New("Cleanup err")
			innerBlobstore.CreateBlobId = "blob-id"

			expectedSha1 := "da39a3ee5e6b4b0d3255bfef95601890afd80709"

			blobId, sha1, err := sha1Verifiable.Create("../../../fixtures/some.config")

			Expect("blob-id").To(Equal(blobId))
			Expect(err).To(Equal(innerBlobstore.CreateErr))
			Expect("../../../fixtures/some.config").To(Equal(innerBlobstore.CreateFileName))
			Expect(expectedSha1).To(Equal(sha1))
		})
	})
}
