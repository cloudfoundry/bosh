package blobstore

import "os"

type dummy struct {
}

func newDummyBlobstore() (blobstore dummy) {
	return
}

func (blobstore dummy) ApplyOptions(opts map[string]string) (updated Blobstore, err error) {
	updated = blobstore
	return
}

func (blobstore dummy) Create(file *os.File) (blobId string, err error) {
	return
}
