package blobstore

import (
	bosherr "bosh/errors"
	boshplatform "bosh/platform"
	boshsettings "bosh/settings"
	boshdir "bosh/settings/directories"
	boshuuid "bosh/uuid"
	"path/filepath"
)

type provider struct {
	blobstores map[boshsettings.BlobstoreType]Blobstore
}

func NewProvider(platform boshplatform.Platform, dirProvider boshdir.DirectoriesProvider) (p provider) {
	fs := platform.GetFs()
	runner := platform.GetRunner()
	uuidGen := boshuuid.NewGenerator()
	s3cliConfigPath := filepath.Join(dirProvider.EtcDir(), "s3cli")

	p.blobstores = map[boshsettings.BlobstoreType]Blobstore{
		boshsettings.BlobstoreTypeDav:   newDummyBlobstore(),
		boshsettings.BlobstoreTypeDummy: newDummyBlobstore(),
		boshsettings.BlobstoreTypeS3:    newS3Blobstore(fs, runner, uuidGen, s3cliConfigPath),
	}
	return
}

func (p provider) Get(settings boshsettings.Blobstore) (blobstore Blobstore, err error) {
	blobstore, found := p.blobstores[settings.Type]

	if !found {
		err = bosherr.New("Blobstore %s could not be found", settings.Type)
		return
	}

	blobstore = NewSha1Verifiable(blobstore)

	blobstore, err = blobstore.ApplyOptions(settings.Options)
	if err != nil {
		err = bosherr.WrapError(err, "Applying Options")
		return
	}
	return
}
