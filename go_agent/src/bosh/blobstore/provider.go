package blobstore

import (
	bosherr "bosh/errors"
	boshplatform "bosh/platform"
	boshsettings "bosh/settings"
	boshuuid "bosh/uuid"
)

type provider struct {
	blobstores map[boshsettings.BlobstoreType]Blobstore
}

func NewProvider(platform boshplatform.Platform) (p provider) {
	fs := platform.GetFs()
	runner := platform.GetRunner()
	uuidGen := boshuuid.NewGenerator()

	p.blobstores = map[boshsettings.BlobstoreType]Blobstore{
		boshsettings.BlobstoreTypeDav:   newDummyBlobstore(),
		boshsettings.BlobstoreTypeDummy: newDummyBlobstore(),
		boshsettings.BlobstoreTypeS3:    newS3Blobstore(fs, runner, uuidGen),
	}
	return
}

func (p provider) Get(settings boshsettings.Blobstore) (blobstore Blobstore, err error) {
	blobstore, found := p.blobstores[settings.Type]

	if !found {
		err = bosherr.New("Blobstore %s could not be found", settings.Type)
		return
	}

	blobstore, err = blobstore.ApplyOptions(settings.Options)
	if err != nil {
		err = bosherr.WrapError(err, "Applying Options")
		return
	}
	return
}
