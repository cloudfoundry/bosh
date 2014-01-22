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

func NewBlobManager(fs boshsys.FileSystem, dirProvider boshdir.DirectoriesProvider) (manager BlobManager) {
	manager.fs = fs
	manager.dirProvider = dirProvider
	return
}

func (manager BlobManager) Fetch(blobId string) (blobBytes []byte, err error) {
	blobPath := filepath.Join(manager.dirProvider.MicroStore(), blobId)

	blobString, err := manager.fs.ReadFile(blobPath)
	if err != nil {
		err = bosherr.WrapError(err, "Reading blob")
		return
	}

	blobBytes = []byte(blobString)
	return
}

func (manager BlobManager) Write(blobId string, blobBytes []byte) (err error) {
	blobPath := filepath.Join(manager.dirProvider.MicroStore(), blobId)

	_, err = manager.fs.WriteToFile(blobPath, string(blobBytes))
	if err != nil {
		err = bosherr.WrapError(err, "Updating blob")
		return
	}

	return
}
