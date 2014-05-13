package blobstore

import (
	"fmt"
	"path/filepath"

	bosherr "bosh/errors"
	boshplatform "bosh/platform"
	boshsettings "bosh/settings"
	boshdir "bosh/settings/directories"
	boshuuid "bosh/uuid"
)

type Provider struct {
	platform    boshplatform.Platform
	dirProvider boshdir.DirectoriesProvider
	uuidGen     boshuuid.Generator
}

func NewProvider(
	platform boshplatform.Platform,
	dirProvider boshdir.DirectoriesProvider,
) (p Provider) {
	p.uuidGen = boshuuid.NewGenerator()
	p.platform = platform
	p.dirProvider = dirProvider
	return
}

func (p Provider) Get(settings boshsettings.Blobstore) (blobstore Blobstore, err error) {
	configName := fmt.Sprintf("blobstore-%s.json", settings.Type)
	externalConfigFile := filepath.Join(p.dirProvider.EtcDir(), configName)

	switch settings.Type {
	case boshsettings.BlobstoreTypeDummy:
		blobstore = newDummyBlobstore()

	case boshsettings.BlobstoreTypeLocal:
		blobstore = NewLocalBlobstore(
			p.platform.GetFs(),
			p.uuidGen,
			settings.Options,
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
