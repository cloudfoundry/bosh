package bootstrap

import (
	testinf "bosh/infrastructure/testhelpers"
	testplatform "bosh/platform/testhelpers"
	boshsettings "bosh/settings"
	testsys "bosh/system/testhelpers"
	"encoding/json"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestRunSetsUpRuntimeConfiguration(t *testing.T) {
	fakeFs, fakeInfrastructure, fakePlatform := getBootstrapDependencies()
	boot := New(fakeFs, fakeInfrastructure, fakePlatform)
	boot.Run()

	assert.True(t, fakePlatform.SetupRuntimeConfigurationWasInvoked)
}

func TestRunSetsUpSsh(t *testing.T) {
	fakeFs, fakeInfrastructure, fakePlatform := getBootstrapDependencies()
	boot := New(fakeFs, fakeInfrastructure, fakePlatform)
	boot.Run()

	assert.Equal(t, fakeInfrastructure.SetupSshDelegate, fakePlatform)
	assert.Equal(t, fakeInfrastructure.SetupSshUsername, "vcap")
}

func TestRunGetsSettingsFromTheInfrastructure(t *testing.T) {
	expectedSettings := boshsettings.Settings{
		AgentId: "123-456-789",
	}

	fakeFs, fakeInfrastructure, fakePlatform := getBootstrapDependencies()
	fakeInfrastructure.Settings = expectedSettings

	boot := New(fakeFs, fakeInfrastructure, fakePlatform)
	boot.Run()

	settingsFileStat := fakeFs.GetFileTestStat(VCAP_BASE_DIR + "/bosh/settings.json")
	settingsJson, err := json.Marshal(expectedSettings)
	assert.NoError(t, err)

	assert.NotNil(t, settingsFileStat)
	assert.Equal(t, settingsFileStat.CreatedWith, "WriteToFile")
	assert.Equal(t, settingsFileStat.Content, string(settingsJson))
}

func TestRunSetsUpHostname(t *testing.T) {
	fakeFs, fakeInfrastructure, fakePlatform := getBootstrapDependencies()
	fakeInfrastructure.Settings = boshsettings.Settings{
		AgentId: "foo-bar-baz-123",
	}

	boot := New(fakeFs, fakeInfrastructure, fakePlatform)
	boot.Run()

	assert.Equal(t, fakePlatform.SetupHostnameHostname, "foo-bar-baz-123")
}

func TestRunSetsUpNetworking(t *testing.T) {
	settings := boshsettings.Settings{
		Networks: boshsettings.Networks{
			"bosh": boshsettings.NetworkSettings{},
		},
	}

	fakeFs, fakeInfrastructure, fakePlatform := getBootstrapDependencies()
	fakeInfrastructure.Settings = settings

	boot := New(fakeFs, fakeInfrastructure, fakePlatform)
	boot.Run()

	assert.Equal(t, fakeInfrastructure.SetupNetworkingDelegate, fakePlatform)
	assert.Equal(t, fakeInfrastructure.SetupNetworkingNetworks, settings.Networks)
}

func TestRunSetsUpEphemeralDisk(t *testing.T) {
	settings := boshsettings.Settings{
		Disks: boshsettings.Disks{
			Ephemeral: "/dev/sda",
		},
	}

	fakeFs, fakeInfrastructure, fakePlatform := getBootstrapDependencies()
	fakeInfrastructure.Settings = settings

	boot := New(fakeFs, fakeInfrastructure, fakePlatform)
	boot.Run()

	assert.Equal(t, fakePlatform.SetupEphemeralDiskWithPathDevicePath, "/dev/sda")
	assert.Equal(t, fakePlatform.SetupEphemeralDiskWithPathMountPoint, "/var/vcap/data")
}

func getBootstrapDependencies() (fs *testsys.FakeFileSystem, inf *testinf.FakeInfrastructure, platform *testplatform.FakePlatform) {
	fs = &testsys.FakeFileSystem{}
	inf = &testinf.FakeInfrastructure{}
	platform = &testplatform.FakePlatform{}
	return
}
