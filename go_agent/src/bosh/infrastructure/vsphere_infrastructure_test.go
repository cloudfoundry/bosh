package infrastructure

import (
	boshsettings "bosh/settings"
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
	vsphere := buildVsphere()

	settings, err := vsphere.GetSettings()

	assert.NoError(t, err)
	assert.Equal(t, settings.AgentId, "123")
}

func TestVsphereSetupNetworking(t *testing.T) {
	vsphere := buildVsphere()
	fakeDelegate := &FakeNetworkingDelegate{}
	networks := boshsettings.Networks{"bosh": boshsettings.Network{}}

	vsphere.SetupNetworking(fakeDelegate, networks)

	assert.Equal(t, fakeDelegate.SetupManualNetworkingNetworks, networks)
}

func buildVsphere() (vsphere vsphereInfrastructure) {
	cdromDelegate := FakeCDROMDelegate{}
	vsphere = newVsphereInfrastructure(cdromDelegate)
	return
}
