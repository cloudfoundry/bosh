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

type Provider struct {
	platform    boshplatform.Platform
	dirProvider boshdir.DirectoriesProvider
	uuidGen     boshuuid.Generator
}

func NewProvider(platform boshplatform.Platform, dirProvider boshdir.DirectoriesProvider) (p Provider) {
	p.uuidGen = boshuuid.NewGenerator()
	p.platform = platform
	p.dirProvider = dirProvider
	return
}

func (p Provider) Get(settings boshsettings.Blobstore) (blobstore Blobstore, err error) {
	externalConfigFile := filepath.Join(p.dirProvider.EtcDir(), fmt.Sprintf("blobstore-%s.json", settings.Type))

	switch settings.Type {
	case boshsettings.BlobstoreTypeDummy:
		blobstore = newDummyBlobstore()
	case boshsettings.BlobstoreTypeLocal:
		blobstore = newLocalBlobstore(
			settings.Options,
			p.platform.GetFs(),
			p.uuidGen,
		)
	default:
		blobstore = NewExternalBlobstore(
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
