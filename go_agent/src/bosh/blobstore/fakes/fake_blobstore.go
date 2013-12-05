package fakes

import (
	boshblobstore "bosh/blobstore"
	"os"
)

type FakeBlobstore struct {
	Options map[string]string

	GetBlobId string
	GetError  error

	CreateFile   *os.File
	CreateBlobId string
}

func NewFakeBlobstore() *FakeBlobstore {
	return &FakeBlobstore{}
}

func (bs *FakeBlobstore) ApplyOptions(opts map[string]string) (updated boshblobstore.Blobstore, err error) {
	bs.Options = opts
	updated = bs
	return
}

func (bs *FakeBlobstore) Get(blobId string) (file *os.File, err error) {
	bs.GetBlobId = blobId
	err = bs.GetError
	return
}

func (bs *FakeBlobstore) CleanUp(file *os.File) (err error) {
	return
}

func (bs *FakeBlobstore) Create(file *os.File) (blobId string, err error) {
	bs.CreateFile = file

	blobId = bs.CreateBlobId
	return
}
