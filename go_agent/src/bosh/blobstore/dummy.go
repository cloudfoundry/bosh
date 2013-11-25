package blobstore

import "os"

type dummy struct {
}

func newDummyBlobstore() (blobstore dummy) {
	return
}

func (blobstore dummy) SetOptions(opts map[string]string) (err error) {
	return
}

func (blobstore dummy) Create(file *os.File) (blobId string, err error) {
	return
}
