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

	settingsFileStat := fakeFs.GetFileTestStat(boshsettings.VCAP_BASE_DIR + "/bosh/settings.json")
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
	assert.Equal(t, fakePlatform.SetupEphemeralDiskWithPathMountPoint, boshsettings.VCAP_BASE_DIR+"/data")
}

func TestRunSetsRootAndVcapPasswords(t *testing.T) {
	fakeFs, fakeInfrastructure, fakePlatform := getBootstrapDependencies()
	fakeInfrastructure.Settings.Env.Bosh.Password = "some-encrypted-password"

	boot := New(fakeFs, fakeInfrastructure, fakePlatform)
	boot.Run()

	assert.Equal(t, 2, len(fakePlatform.UserPasswords))
	assert.Equal(t, "some-encrypted-password", fakePlatform.UserPasswords["root"])
	assert.Equal(t, "some-encrypted-password", fakePlatform.UserPasswords["vcap"])
}

func TestRunDoesNotSetPasswordIfNotProvided(t *testing.T) {
	settings := boshsettings.Settings{}

	fakeFs, fakeInfrastructure, fakePlatform := getBootstrapDependencies()
	fakeInfrastructure.Settings = settings

	boot := New(fakeFs, fakeInfrastructure, fakePlatform)
	boot.Run()

	assert.Equal(t, 0, len(fakePlatform.UserPasswords))
}

func TestRunSetsTime(t *testing.T) {
	fakeFs, fakeInfrastructure, fakePlatform := getBootstrapDependencies()
	fakeInfrastructure.Settings.Ntp = []string{"0.north-america.pool.ntp.org", "1.north-america.pool.ntp.org"}

	boot := New(fakeFs, fakeInfrastructure, fakePlatform)
	boot.Run()

	assert.Equal(t, 2, len(fakePlatform.SetTimeWithNtpServersServers))
	assert.Equal(t, "0.north-america.pool.ntp.org", fakePlatform.SetTimeWithNtpServersServers[0])
	assert.Equal(t, "1.north-america.pool.ntp.org", fakePlatform.SetTimeWithNtpServersServers[1])
	assert.Equal(t, boshsettings.VCAP_BASE_DIR+"/bosh/etc/ntpserver", fakePlatform.SetTimeWithNtpServersServersFilePath)
}

func getBootstrapDependencies() (fs *testsys.FakeFileSystem, inf *testinf.FakeInfrastructure, platform *testplatform.FakePlatform) {
	fs = &testsys.FakeFileSystem{}
	inf = &testinf.FakeInfrastructure{}
	platform = testplatform.NewFakePlatform()
	return
}
