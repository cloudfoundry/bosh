package blobstore

import (
	bosherr "bosh/errors"
	"crypto/sha1"
	"fmt"
	"io"
	"os"
)

type sha1Verifiable struct {
	blobstore Blobstore
}

func NewSha1Verifiable(blobstore Blobstore) Blobstore {
	return sha1Verifiable{
		blobstore: blobstore,
	}
}

func (b sha1Verifiable) Get(blobId, fingerprint string) (fileName string, err error) {
	fileName, err = b.blobstore.Get(blobId, fingerprint)
	if err != nil {
		err = bosherr.WrapError(err, "Getting blob from inner blobstore")
		return
	}

	if fingerprint == "" {
		return
	}

	actualSha1, err := calculateSha1(fileName)
	if err != nil {
		return
	}

	if actualSha1 != fingerprint {
		err = bosherr.New("SHA1 mismatch. Expected %s, got %s for blob %s", fingerprint, actualSha1, fileName)

	}
	return
}

func (b sha1Verifiable) CleanUp(fileName string) (err error) {
	return b.blobstore.CleanUp(fileName)
}

func (b sha1Verifiable) Create(fileName string) (blobId string, fingerprint string, err error) {
	fingerprint, err = calculateSha1(fileName)
	if err != nil {
		return
	}

	blobId, _, err = b.blobstore.Create(fileName)
	return
}

func calculateSha1(fileName string) (fingerprint string, err error) {
	file, err := os.Open(fileName)
	if err != nil {
		err = bosherr.WrapError(err, "Opening file for sha1 calculation")
		return
	}
	defer file.Close()

	h := sha1.New()
	io.Copy(h, file)
	fingerprint = fmt.Sprintf("%x", h.Sum(nil))
	return
}

func (b sha1Verifiable) Validate() (err error) {
	return b.blobstore.Validate()
}
