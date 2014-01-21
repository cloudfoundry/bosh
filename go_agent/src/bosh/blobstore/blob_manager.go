package blobstore

import (
	bosherr "bosh/errors"
	boshdir "bosh/settings/directories"
	boshsys "bosh/system"
	"path/filepath"
)

type BlobManager struct {
	fs          boshsys.FileSystem
	dirProvider boshdir.DirectoriesProvider
}

func NewBlobManager(fs boshsys.FileSystem, dirProvider boshdir.DirectoriesProvider) (fetcher BlobManager) {
	fetcher.fs = fs
	fetcher.dirProvider = dirProvider
	return
}

func (fetcher BlobManager) Fetch(blobId string) (blobBytes []byte, err error) {
	blobPath := filepath.Join(fetcher.dirProvider.MicroStore(), blobId)

	blobString, err := fetcher.fs.ReadFile(blobPath)
	if err != nil {
		err = bosherr.WrapError(err, "Reading blob")
		return
	}

	blobBytes = []byte(blobString)
	return
}
