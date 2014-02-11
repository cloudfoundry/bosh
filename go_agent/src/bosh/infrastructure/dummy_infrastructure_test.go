package infrastructure_test

import (
	. "bosh/infrastructure"
	fakeplatform "bosh/platform/fakes"
	boshsettings "bosh/settings"
	boshdir "bosh/settings/directories"
	fakefs "bosh/system/fakes"
	"encoding/json"
	"github.com/stretchr/testify/assert"
	"path/filepath"
	"testing"
)

func TestGetSettings(t *testing.T) {
	fs := fakefs.NewFakeFileSystem()
	dirProvider := boshdir.NewDirectoriesProvider("/var/vcap")
	platform := fakeplatform.NewFakePlatform()

	settingsPath := filepath.Join(dirProvider.BaseDir(), "bosh", "settings.json")

	expectedSettings := boshsettings.Settings{AgentId: "123-456-789", Blobstore: boshsettings.Blobstore{Type: boshsettings.BlobstoreTypeDummy}, Mbus: "nats://127.0.0.1:4222"}
	existingSettingsBytes, _ := json.Marshal(expectedSettings)
	fs.WriteToFile(settingsPath, string(existingSettingsBytes))

	dummy := NewDummyInfrastructure(fs, dirProvider, platform)

	settings, err := dummy.GetSettings()
	assert.NoError(t, err)

	assert.Equal(t, settings, boshsettings.Settings{
		AgentId:   "123-456-789",
		Blobstore: boshsettings.Blobstore{Type: boshsettings.BlobstoreTypeDummy},
		Mbus:      "nats://127.0.0.1:4222",
	})
}

func TestGetSettingsErrsWhenSettingsFileDoesNotExist(t *testing.T) {
	fs := fakefs.NewFakeFileSystem()
	dirProvider := boshdir.NewDirectoriesProvider("/var/vcap")
	platform := fakeplatform.NewFakePlatform()

	dummy := NewDummyInfrastructure(fs, dirProvider, platform)

	_, err := dummy.GetSettings()
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "Read settings file")
}
