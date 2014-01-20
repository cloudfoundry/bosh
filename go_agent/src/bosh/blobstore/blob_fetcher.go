package blobstore

import (
	bosherr "bosh/errors"
	boshdir "bosh/settings/directories"
	boshsys "bosh/system"
	"path/filepath"
)

type BlobFetcher struct {
	fs          boshsys.FileSystem
	dirProvider boshdir.DirectoriesProvider
}

func NewBlobFetcher(fs boshsys.FileSystem, dirProvider boshdir.DirectoriesProvider) (fetcher BlobFetcher) {
	fetcher.fs = fs
	fetcher.dirProvider = dirProvider
	return
}

func (fetcher BlobFetcher) Fetch(blobId string) (blobBytes []byte, err error) {
	blobPath := filepath.Join(fetcher.dirProvider.MicroStore(), blobId)

	blobString, err := fetcher.fs.ReadFile(blobPath)
	if err != nil {
		err = bosherr.WrapError(err, "Reading blob")
		return
	}

	blobBytes = []byte(blobString)
	return
}
