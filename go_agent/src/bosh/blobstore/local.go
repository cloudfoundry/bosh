package blobstore

import (
	"path/filepath"

	bosherr "bosh/errors"
	boshsys "bosh/system"
	boshuuid "bosh/uuid"
)

type local struct {
	fs      boshsys.FileSystem
	uuidGen boshuuid.Generator
	options map[string]interface{}
}

func NewLocalBlobstore(
	fs boshsys.FileSystem,
	uuidGen boshuuid.Generator,
	options map[string]interface{},
) local {
	return local{
		fs:      fs,
		uuidGen: uuidGen,
		options: options,
	}
}

func (blobstore local) Get(blobID, _ string) (fileName string, err error) {
	file, err := blobstore.fs.TempFile("bosh-blobstore-external-Get")
	if err != nil {
		return "", bosherr.WrapError(err, "Creating temporary file")
	}

	fileName = file.Name()

	err = blobstore.fs.CopyFile(filepath.Join(blobstore.path(), blobID), fileName)
	if err != nil {
		blobstore.fs.RemoveAll(fileName)
		return "", bosherr.WrapError(err, "Copying file")
	}

	return fileName, nil
}

func (blobstore local) CleanUp(fileName string) error {
	blobstore.fs.RemoveAll(fileName)
	return nil
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

func (blobstore local) Validate() error {
	path, found := blobstore.options["blobstore_path"]
	if !found {
		return bosherr.New("missing blobstore_path")
	}

	_, ok := path.(string)
	if !ok {
		return bosherr.New("blobstore_path must be a string")
	}

	return nil
}

func (blobstore local) path() string {
	// Validate() makes sure that it's a string
	return blobstore.options["blobstore_path"].(string)
}
