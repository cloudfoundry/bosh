package blobstore

import (
	bosherr "bosh/errors"
	boshsettings "bosh/settings"
)

type provider struct {
	blobstores map[boshsettings.BlobstoreType]Blobstore
}

func NewProvider() (p provider) {
	p.blobstores = map[boshsettings.BlobstoreType]Blobstore{
		boshsettings.BlobstoreTypeS3:    newS3Blobstore(),
		boshsettings.BlobstoreTypeDummy: newDummyBlobstore(),
	}
	return
}

func (p provider) Get(settings boshsettings.Blobstore) (blobstore Blobstore, err error) {
	blobstore, found := p.blobstores[settings.Type]

	if !found {
		err = bosherr.New("Blobstore %s could not be found", settings.Type)
		return
	}

	err = blobstore.SetOptions(settings.Options)
	if err != nil {
		err = bosherr.WrapError(err, "Applying Options")
		return
	}
	return
}
