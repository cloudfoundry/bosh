package blobstore

import (
	bosherr "bosh/errors"
	boshplatform "bosh/platform"
	boshsettings "bosh/settings"
	boshdir "bosh/settings/directories"
	boshuuid "bosh/uuid"
	"fmt"
	"path/filepath"
)

type provider struct {
	blobstores  map[string]Blobstore
	platform    boshplatform.Platform
	dirProvider boshdir.DirectoriesProvider
	uuidGen     boshuuid.Generator
}

func NewProvider(platform boshplatform.Platform, dirProvider boshdir.DirectoriesProvider) (p provider) {
	p.uuidGen = boshuuid.NewGenerator()
	p.platform = platform
	p.dirProvider = dirProvider
	return
}

func (p provider) Get(settings boshsettings.Blobstore) (blobstore Blobstore, err error) {
	externalConfigFile := filepath.Join(p.dirProvider.EtcDir(), fmt.Sprintf("blobstore-%s.json", settings.Type))

	switch settings.Type {
	case boshsettings.BlobstoreTypeDav:
		blobstore = newDummyBlobstore()
	case boshsettings.BlobstoreTypeDummy:
		blobstore = newDummyBlobstore()
	case boshsettings.BlobstoreTypeS3:
		blobstore = newS3Blobstore(
			settings.Options,
			p.platform.GetFs(),
			p.platform.GetRunner(),
			p.uuidGen,
			externalConfigFile,
		)
	case boshsettings.BlobstoreTypeLocal:
		blobstore = newLocalBlobstore(
			settings.Options,
			p.platform.GetFs(),
			p.uuidGen,
		)
	default:
		blobstore = newExternalBlobstore(
			settings.Type,
			settings.Options,
			p.platform.GetFs(),
			p.platform.GetRunner(),
			p.uuidGen,
			externalConfigFile,
		)
	}

	blobstore = NewSha1Verifiable(blobstore)

	err = blobstore.Validate()
	if err != nil {
		err = bosherr.WrapError(err, "Validating blobstore")
	}
	return
}
