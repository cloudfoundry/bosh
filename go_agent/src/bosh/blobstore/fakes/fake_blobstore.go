package fakes

import "os"

type FakeBlobstore struct {
	Options      map[string]string
	CreateFile   *os.File
	CreateBlobId string
}

func (bs *FakeBlobstore) SetOptions(opts map[string]string) (err error) {
	bs.Options = opts
	return
}

func (bs *FakeBlobstore) Create(file *os.File) (blobId string, err error) {
	bs.CreateFile = file

	blobId = bs.CreateBlobId
	return
}
