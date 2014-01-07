package blobstore_test

import (
	boshblob "bosh/blobstore"
	fakeblob "bosh/blobstore/fakes"
	bosherr "bosh/errors"
	"errors"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestSha1VerifiableValidate(t *testing.T) {
	innerBlobstore, sha1Verifiable := buildSha1Verifiable()

	err := sha1Verifiable.Validate()
	assert.NoError(t, err)

	innerBlobstore.ValidateError = bosherr.New("fake-error")
	err = sha1Verifiable.Validate()
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "fake-error")
}

func TestSha1VerifiableGetWhenSha1IsCorrect(t *testing.T) {
	innerBlobstore, sha1Verifiable := buildSha1Verifiable()

	innerBlobstore.GetFileName = "../../../fixtures/some.config"
	validSha1 := "da39a3ee5e6b4b0d3255bfef95601890afd80709"

	fileName, err := sha1Verifiable.Get("some-blob-id", validSha1)
	assert.NoError(t, err)
	assert.Equal(t, innerBlobstore.GetFileName, fileName)
}

func TestSha1VerifiableGetWhenSha1IsIncorrect(t *testing.T) {
	innerBlobstore, sha1Verifiable := buildSha1Verifiable()

	innerBlobstore.GetFileName = "../../../fixtures/some.config"
	incorrectSha1 := "some-incorrect-sha1"

	_, err := sha1Verifiable.Get("some-blob-id", incorrectSha1)
	assert.Error(t, err)
}

func TestSha1VerifiableErrsWhenGetErrs(t *testing.T) {
	innerBlobstore, sha1Verifiable := buildSha1Verifiable()
	innerBlobstore.GetError = errors.New("Error getting blob")
	validSha1 := "da39a3ee5e6b4b0d3255bfef95601890afd80709"

	_, err := sha1Verifiable.Get("some-blob-id", validSha1)
	assert.Contains(t, err.Error(), innerBlobstore.GetError.Error())
}

func TestSha1VerifiableSkipsTestingsIfSha1IsEmpty(t *testing.T) {
	innerBlobstore, sha1Verifiable := buildSha1Verifiable()

	innerBlobstore.GetFileName = "../../../fixtures/some.config"
	emptySha1 := ""

	fileName, err := sha1Verifiable.Get("some-blob-id", emptySha1)
	assert.NoError(t, err)
	assert.Equal(t, innerBlobstore.GetFileName, fileName)
}

func TestSha1VerifiableCleanup(t *testing.T) {
	innerBlobstore, sha1Verifiable := buildSha1Verifiable()
	innerBlobstore.CleanUpErr = errors.New("Cleanup err")

	err := sha1Verifiable.CleanUp("/some/file")

	assert.Equal(t, err, innerBlobstore.CleanUpErr)
	assert.Equal(t, "/some/file", innerBlobstore.CleanUpFileName)
}

func TestSha1VerifiableCreate(t *testing.T) {
	innerBlobstore, sha1Verifiable := buildSha1Verifiable()
	innerBlobstore.CreateErr = errors.New("Cleanup err")
	innerBlobstore.CreateBlobId = "blob-id"

	expectedSha1 := "da39a3ee5e6b4b0d3255bfef95601890afd80709"

	blobId, sha1, err := sha1Verifiable.Create("../../../fixtures/some.config")

	assert.Equal(t, "blob-id", blobId)
	assert.Equal(t, err, innerBlobstore.CreateErr)
	assert.Equal(t, "../../../fixtures/some.config", innerBlobstore.CreateFileName)
	assert.Equal(t, expectedSha1, sha1)
}

func buildSha1Verifiable() (innerBlobstore *fakeblob.FakeBlobstore, sha1Verifiable boshblob.Blobstore) {
	innerBlobstore = &fakeblob.FakeBlobstore{}
	sha1Verifiable = boshblob.NewSha1Verifiable(innerBlobstore)
	return
}
