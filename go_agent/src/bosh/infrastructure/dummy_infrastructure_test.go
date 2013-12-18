package infrastructure

import (
	boshsettings "bosh/settings"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestGetSettings(t *testing.T) {
	dummy := newDummyInfrastructure()
	settings, err := dummy.GetSettings()
	assert.NoError(t, err)

	assert.Equal(t, settings, boshsettings.Settings{
		AgentId:   "123-456-789",
		Blobstore: boshsettings.Blobstore{Type: boshsettings.BlobstoreTypeDummy},
		Mbus:      "nats://127.0.0.1:4222",
	})
}
