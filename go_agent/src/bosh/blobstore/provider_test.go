package blobstore

import (
	boshplatform "bosh/platform"
	fakeplatform "bosh/platform/fakes"
	boshsettings "bosh/settings"
	boshdir "bosh/settings/directories"
	boshuuid "bosh/uuid"
	"github.com/stretchr/testify/assert"
	"path/filepath"
	"testing"
)

func TestGetDav(t *testing.T) {
	_, _, provider := buildProvider()
	blobstore, err := provider.Get(boshsettings.Blobstore{
		Type: boshsettings.BlobstoreTypeDav,
	})
	assert.NoError(t, err)
	assert.NotNil(t, blobstore)
}

func TestGetDummy(t *testing.T) {
	_, _, provider := buildProvider()
	blobstore, err := provider.Get(boshsettings.Blobstore{
		Type: boshsettings.BlobstoreTypeDummy,
	})
	assert.NoError(t, err)
	assert.NotNil(t, blobstore)
}

func TestGetS3(t *testing.T) {
	platform, dirProvider, provider := buildProvider()
	options := map[string]string{
		"access_key_id":     "some-access-key",
		"secret_access_key": "some-secret-key",
		"bucket_name":       "some-bucket",
	}
	blobstore, err := provider.Get(boshsettings.Blobstore{
		Type:    boshsettings.BlobstoreTypeS3,
		Options: options,
	})
	assert.NoError(t, err)

	expectedS3ConfigPath := filepath.Join(dirProvider.EtcDir(), "s3cli")
	expectedBlobstore := newS3Blobstore(platform.GetFs(), platform.GetRunner(), boshuuid.NewGenerator(), expectedS3ConfigPath)
	expectedBlobstore = NewSha1Verifiable(expectedBlobstore)
	expectedBlobstore, err = expectedBlobstore.ApplyOptions(options)

	assert.NoError(t, err)
	assert.Equal(t, blobstore, expectedBlobstore)
}

func buildProvider() (platform boshplatform.Platform, dirProvider boshdir.DirectoriesProvider, provider provider) {
	platform = fakeplatform.NewFakePlatform()
	dirProvider = boshdir.NewDirectoriesProvider("/var/vcap")
	provider = NewProvider(platform, dirProvider)
	return
}
