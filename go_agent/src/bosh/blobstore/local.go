package blobstore

import (
	bosherr "bosh/errors"
	boshsys "bosh/system"
	boshuuid "bosh/uuid"
	"path/filepath"
)

type local struct {
	fs      boshsys.FileSystem
	uuidGen boshuuid.Generator
	options map[string]string
}

func newLocalBlobstore(options map[string]string, fs boshsys.FileSystem, uuidGen boshuuid.Generator) (blobstore local) {
	return local{
		fs:      fs,
		uuidGen: uuidGen,
		options: options,
	}
}

func (blobstore local) Validate() (err error) {
	_, found := blobstore.options["blobstore_path"]
	if !found {
		err = bosherr.New("missing blobstore_path")
		return
	}
	return
}

func (blobstore local) Get(blobID, _ string) (fileName string, err error) {
	file, err := blobstore.fs.TempFile("bosh-blobstore-external-Get")
	if err != nil {
		err = bosherr.WrapError(err, "Creating temporary file")
		return
	}

	fileName = file.Name()

	err = blobstore.fs.CopyFile(filepath.Join(blobstore.path(), blobID), fileName)
	if err != nil {
		err = bosherr.WrapError(err, "Copying file")
		blobstore.fs.RemoveAll(fileName)
		fileName = ""
	}

	return
}

func (blobstore local) CleanUp(fileName string) (err error) {
	blobstore.fs.RemoveAll(fileName)
	return
}

func (blobstore local) Create(fileName string) (blobID string, fingerprint string, err error) {
	blobID, err = blobstore.uuidGen.Generate()
	if err != nil {
		err = bosherr.WrapError(err, "Generating blobID")
		return
	}

	err = blobstore.fs.CopyFile(fileName, filepath.Join(blobstore.path(), blobID))
	if err != nil {
		err = bosherr.WrapError(err, "Copying file to blobstore path")
		blobID = ""
		return
	}
	return
}

func (blobstore local) path() (path string) {
	return blobstore.options["blobstore_path"]
}
