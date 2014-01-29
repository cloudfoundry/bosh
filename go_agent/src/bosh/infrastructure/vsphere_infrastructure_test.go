package infrastructure

import (
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

func TestVsphereFindPossibleDiskDevice(t *testing.T) {
	vsphere, fs := buildVsphere()

	fs.WriteToFile("/dev/sdb", "")

	path, found := vsphere.FindPossibleDiskDevice("", fs)
	assert.Equal(t, path, "/dev/sdb")
	assert.True(t, found)
}

func buildVsphere() (vsphere vsphereInfrastructure, fs *fakefs.FakeFileSystem) {
	cdromDelegate := FakeCDROMDelegate{}
	vsphere = newVsphereInfrastructure(cdromDelegate)
	fs = fakefs.NewFakeFileSystem()
	return
}
