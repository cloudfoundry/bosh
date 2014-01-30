package infrastructure

import (
	boshsettings "bosh/settings"
	fakefs "bosh/system/fakes"
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
	vsphere, _ := buildVsphere()

	settings, err := vsphere.GetSettings()

	assert.NoError(t, err)
	assert.Equal(t, settings.AgentId, "123")
}

func TestVsphereGetEphemeralDiskPath(t *testing.T) {
	vsphere, fs := buildVsphere()

	fs.WriteToFile("/dev/sdb", "")

	path, found := vsphere.GetEphemeralDiskPath("", fs)
	assert.Equal(t, path, "/dev/sdb")
	assert.True(t, found)
}

func TestVsphereSetupNetworking(t *testing.T) {
	vsphere, _ := buildVsphere()
	fakeDelegate := &FakeNetworkingDelegate{}
	networks := boshsettings.Networks{"bosh": boshsettings.Network{}}

	vsphere.SetupNetworking(fakeDelegate, networks)

	assert.Equal(t, fakeDelegate.SetupManualNetworkingNetworks, networks)
}

func buildVsphere() (vsphere vsphereInfrastructure, fs *fakefs.FakeFileSystem) {
	cdromDelegate := FakeCDROMDelegate{}
	vsphere = newVsphereInfrastructure(cdromDelegate)
	fs = fakefs.NewFakeFileSystem()
	return
}
