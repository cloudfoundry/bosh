package blobstore

import "os"

type dummy struct{}

func newDummyBlobstore() (blobstore dummy) {
	return
}

func (blobstore dummy) ApplyOptions(opts map[string]string) (updated Blobstore, err error) {
	updated = blobstore
	return
}

func (blobstore dummy) Get(blobId string) (file *os.File, err error) {
	return
}

func (blobstore dummy) CleanUp(file *os.File) (err error) {
	return
}

func (blobstore dummy) Create(file *os.File) (blobId string, err error) {
	return
}
