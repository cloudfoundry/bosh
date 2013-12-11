package fakes

import (
	boshblob "bosh/blobstore"
)

type FakeBlobstore struct {
	Options map[string]string

	GetBlobIds  []string
	GetFileName string
	GetError    error

	CleanUpFileName string

	CreateFileName string
	CreateBlobId   string
}

func NewFakeBlobstore() *FakeBlobstore {
	return &FakeBlobstore{}
}

func (bs *FakeBlobstore) ApplyOptions(opts map[string]string) (updated boshblob.Blobstore, err error) {
	bs.Options = opts
	updated = bs
	return
}

func (bs *FakeBlobstore) Get(blobId string) (fileName string, err error) {
	bs.GetBlobIds = append(bs.GetBlobIds, blobId)
	fileName = bs.GetFileName
	err = bs.GetError
	return
}

func (bs *FakeBlobstore) CleanUp(fileName string) (err error) {
	bs.CleanUpFileName = fileName
	return
}

func (bs *FakeBlobstore) Create(fileName string) (blobId string, err error) {
	bs.CreateFileName = fileName

	blobId = bs.CreateBlobId
	return
}
