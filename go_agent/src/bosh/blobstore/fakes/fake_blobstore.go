package fakes

import (
	boshblobstore "bosh/blobstore"
	"os"
)

type FakeBlobstore struct {
	Options map[string]string

	GetBlobId string
	GetFile   *os.File
	GetError  error

	CleanUpFile *os.File

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
	file = bs.GetFile
	err = bs.GetError
	return
}

func (bs *FakeBlobstore) CleanUp(file *os.File) (err error) {
	bs.CleanUpFile = file
	return
}

func (bs *FakeBlobstore) Create(file *os.File) (blobId string, err error) {
	bs.CreateFile = file

	blobId = bs.CreateBlobId
	return
}
