package blobstore

import (
	fakeplatform "bosh/platform/fakes"
	boshsettings "bosh/settings"
	boshdir "bosh/settings/directories"
	boshuuid "bosh/uuid"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestGetDummy(t *testing.T) {
	_, provider := buildProvider()
	blobstore, err := provider.Get(boshsettings.Blobstore{
		Type: boshsettings.BlobstoreTypeDummy,
	})
	assert.NoError(t, err)
	assert.NotNil(t, blobstore)
}

func TestGetExternalWhenExternalCommandInPath(t *testing.T) {
	platform, provider := buildProvider()
	options := map[string]string{
		"key": "value",
	}

	platform.Runner.CommandExistsValue = true
	blobstore, err := provider.Get(boshsettings.Blobstore{
		Type:    "fake-external-type",
		Options: options,
	})
	assert.NoError(t, err)

	expectedExternalConfigPath := "/var/vcap/bosh/etc/blobstore-fake-external-type.json"
	expectedBlobstore := newExternalBlobstore("fake-external-type", options, platform.GetFs(), platform.GetRunner(), boshuuid.NewGenerator(), expectedExternalConfigPath)
	expectedBlobstore = NewSha1Verifiable(expectedBlobstore)
	err = expectedBlobstore.Validate()

	assert.NoError(t, err)
	assert.Equal(t, blobstore, expectedBlobstore)
}

func TestGetExternalErrsWhenExternalCommandNotInPath(t *testing.T) {
	platform, provider := buildProvider()
	options := map[string]string{
		"key": "value",
	}

	platform.Runner.CommandExistsValue = false
	_, err := provider.Get(boshsettings.Blobstore{
		Type:    "fake-external-type",
		Options: options,
	})
	assert.Error(t, err)
}

func buildProvider() (platform *fakeplatform.FakePlatform, provider provider) {
	platform = fakeplatform.NewFakePlatform()
	dirProvider := boshdir.NewDirectoriesProvider("/var/vcap")
	provider = NewProvider(platform, dirProvider)
	return
}
