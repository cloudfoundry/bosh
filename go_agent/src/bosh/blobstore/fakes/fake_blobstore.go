package fakes

import (
	boshblobstore "bosh/blobstore"
	"os"
)

type FakeBlobstore struct {
	Options      map[string]string
	CreateFile   *os.File
	CreateBlobId string
}

func (bs *FakeBlobstore) ApplyOptions(opts map[string]string) (updated boshblobstore.Blobstore, err error) {
	bs.Options = opts
	updated = bs
	return
}

func (bs *FakeBlobstore) Create(file *os.File) (blobId string, err error) {
	bs.CreateFile = file

	blobId = bs.CreateBlobId
	return
}
