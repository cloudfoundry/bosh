package infrastructure

import (
	boshsettings "bosh/settings"
	fakefs "bosh/system/fakes"
	"github.com/stretchr/testify/assert"
	"testing"
	"time"
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

type FakeScsiDelegate struct {
	RescanScsiBusCalled bool
}

func (f *FakeScsiDelegate) RescanScsiBus() {
	f.RescanScsiBusCalled = true
}

func TestVsphereGetPersistentDiskPath(t *testing.T) {
	vsphere, fs := buildVsphere()

	fakeScsiDelegate := &FakeScsiDelegate{}
	fs.GlobPaths = []string{"/sys/bus/scsi/devices/2:0:2:0/block/sdc"}

	diskPath, found := vsphere.GetPersistentDiskPath("2", fs, fakeScsiDelegate)
	assert.True(t, fakeScsiDelegate.RescanScsiBusCalled)
	assert.Equal(t, fs.GlobPattern, "/sys/bus/scsi/devices/2:0:2:0/block/*")
	assert.Equal(t, diskPath, "/dev/sdc")
	assert.True(t, found)
}

func TestVsphereGetPersistentDiskPathWhenNeverFound(t *testing.T) {
	vsphere, fs := buildVsphere()
	vsphere.persistentDiskRetryInterval = 1 * time.Millisecond

	fakeScsiDelegate := &FakeScsiDelegate{}

	_, found := vsphere.GetPersistentDiskPath("2", fs, fakeScsiDelegate)
	assert.False(t, found)
}

func buildVsphere() (vsphere vsphereInfrastructure, fs *fakefs.FakeFileSystem) {
	cdromDelegate := FakeCDROMDelegate{}
	vsphere = newVsphereInfrastructure(cdromDelegate)
	fs = fakefs.NewFakeFileSystem()
	return
}
