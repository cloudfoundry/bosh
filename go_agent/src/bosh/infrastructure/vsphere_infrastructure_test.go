package infrastructure

import (
	fakeplatform "bosh/platform/fakes"
	boshsettings "bosh/settings"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestVsphereGetSettings(t *testing.T) {
	vsphere, platform := buildVsphere()

	platform.GetFileContentsFromCDROMContents = []byte(`{"agent_id": "123"}`)

	settings, err := vsphere.GetSettings()

	assert.NoError(t, err)
	assert.Equal(t, platform.GetFileContentsFromCDROMPath, "env")
	assert.Equal(t, settings.AgentId, "123")
}

func TestVsphereSetupNetworking(t *testing.T) {
	vsphere, platform := buildVsphere()
	networks := boshsettings.Networks{"bosh": boshsettings.Network{}}

	vsphere.SetupNetworking(networks)

	assert.Equal(t, platform.SetupManualNetworkingNetworks, networks)
}

func TestVsphereGetEphemeralDiskPath(t *testing.T) {
	vsphere, platform := buildVsphere()

	platform.NormalizeDiskPathRealPath = "/dev/sdb"
	platform.NormalizeDiskPathFound = true

	realPath, found := vsphere.GetEphemeralDiskPath("does not matter")
	assert.True(t, found)
	assert.Equal(t, realPath, "/dev/sdb")
	assert.Equal(t, platform.NormalizeDiskPathPath, "/dev/sdb")
}

func buildVsphere() (vsphere vsphereInfrastructure, platform *fakeplatform.FakePlatform) {
	platform = fakeplatform.NewFakePlatform()
	vsphere = newVsphereInfrastructure(platform)
	return
}
