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
	fs := platform.GetFs()
	runner := platform.GetRunner()
	p.uuidGen = boshuuid.NewGenerator()
	s3cliConfigPath := filepath.Join(dirProvider.EtcDir(), "s3cli")

	p.platform = platform
	p.dirProvider = dirProvider
	p.blobstores = map[string]Blobstore{
		boshsettings.BlobstoreTypeDav:   newDummyBlobstore(),
		boshsettings.BlobstoreTypeDummy: newDummyBlobstore(),
		boshsettings.BlobstoreTypeS3:    newS3Blobstore(fs, runner, p.uuidGen, s3cliConfigPath),
	}
	return
}

func (p provider) Get(settings boshsettings.Blobstore) (blobstore Blobstore, err error) {
	blobstore, found := p.blobstores[settings.Type]

	if !found {
		config := filepath.Join(p.dirProvider.EtcDir(), fmt.Sprintf("blobstore-%s.json", settings.Type))
		blobstore = newExternalBlobstore(settings.Type, p.platform.GetFs(), p.platform.GetRunner(), p.uuidGen, config)
		if !blobstore.Valid() {
			err = bosherr.New("Blobstore %s could not be found", settings.Type)
			return
		}
	}

	blobstore = NewSha1Verifiable(blobstore)

	blobstore, err = blobstore.ApplyOptions(settings.Options)
	if err != nil {
		err = bosherr.WrapError(err, "Applying Options")
		return
	}
	return
}
