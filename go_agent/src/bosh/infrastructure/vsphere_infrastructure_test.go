package infrastructure

import (
	"github.com/stretchr/testify/assert"
	"testing"
)

type FakeCDROMDelegate struct {
}

func (fakeCDROMDelegate FakeCDROMDelegate) GetFileContentsFromCDROM(_ string) (contents []byte, err error) {
	contents = []byte(`{"agent_id": "123"}`)
	return
}

func TestVsphereGetSettings(t *testing.T) {
	cdromDelegate := FakeCDROMDelegate{}
	vsphere := newVsphereInfrastructure(cdromDelegate)

	settings, err := vsphere.GetSettings()

	assert.NoError(t, err)
	assert.Equal(t, settings.AgentId, "123")
}
