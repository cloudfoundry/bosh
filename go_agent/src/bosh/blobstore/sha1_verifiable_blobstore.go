package blobstore

import (
	"crypto/sha1"
	"fmt"
	"io"
	"os"

	bosherr "bosh/errors"
)

type sha1VerifiableBlobstore struct {
	blobstore Blobstore
}

func NewSHA1VerifiableBlobstore(blobstore Blobstore) Blobstore {
	return sha1VerifiableBlobstore{blobstore: blobstore}
}

func (b sha1VerifiableBlobstore) Get(blobID, fingerprint string) (string, error) {
	fileName, err := b.blobstore.Get(blobID, fingerprint)
	if err != nil {
		return "", bosherr.WrapError(err, "Getting blob from inner blobstore")
	}

	if fingerprint == "" {
		return fileName, nil
	}

	actualSha1, err := calculateSha1(fileName)
	if err != nil {
		return "", err
	}

	if actualSha1 != fingerprint {
		return "", bosherr.New("SHA1 mismatch. Expected %s, got %s for blob %s", fingerprint, actualSha1, fileName)
	}

	return fileName, nil
}

func (b sha1VerifiableBlobstore) CleanUp(fileName string) error {
	return b.blobstore.CleanUp(fileName)
}

func (b sha1VerifiableBlobstore) Create(fileName string) (blobID string, fingerprint string, err error) {
	fingerprint, err = calculateSha1(fileName)
	if err != nil {
		return
	}

	blobID, _, err = b.blobstore.Create(fileName)
	return
}

func calculateSha1(fileName string) (string, error) {
	file, err := os.Open(fileName)
	if err != nil {
		return "", bosherr.WrapError(err, "Opening file for sha1 calculation")
	}

	defer file.Close()

	h := sha1.New()

	_, err = io.Copy(h, file)
	if err != nil {
		return "", bosherr.WrapError(err, "Copying file for sha1 calculation")
	}

	return fmt.Sprintf("%x", h.Sum(nil)), nil
}

func (b sha1VerifiableBlobstore) Validate() error {
	return b.blobstore.Validate()
}
