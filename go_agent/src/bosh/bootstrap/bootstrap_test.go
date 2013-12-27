package bootstrap

import (
	fakeinf "bosh/infrastructure/fakes"
	fakeplatform "bosh/platform/fakes"
	boshsettings "bosh/settings"
	boshdir "bosh/settings/directories"
	fakesys "bosh/system/fakes"
	"encoding/json"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestRunSetsUpRuntimeConfiguration(t *testing.T) {
	fakeInfrastructure, fakePlatform, dirProvider := getBootstrapDependencies()
	boot := New(fakeInfrastructure, fakePlatform, dirProvider)
	boot.Run()

	assert.True(t, fakePlatform.SetupRuntimeConfigurationWasInvoked)
}

func TestRunSetsUpSsh(t *testing.T) {
	fakeInfrastructure, fakePlatform, dirProvider := getBootstrapDependencies()
	boot := New(fakeInfrastructure, fakePlatform, dirProvider)
	boot.Run()

	assert.Equal(t, fakeInfrastructure.SetupSshDelegate, fakePlatform)
	assert.Equal(t, fakeInfrastructure.SetupSshUsername, "vcap")
}

func TestRunGetsSettingsFromTheInfrastructure(t *testing.T) {
	expectedSettings := boshsettings.Settings{
		AgentId: "123-456-789",
	}

	fakeInfrastructure, fakePlatform, dirProvider := getBootstrapDependencies()
	fakeInfrastructure.Settings = expectedSettings

	boot := New(fakeInfrastructure, fakePlatform, dirProvider)
	settingsService, err := boot.Run()
	assert.NoError(t, err)

	settingsFileStat := fakePlatform.Fs.GetFileTestStat(dirProvider.BaseDir() + "/bosh/settings.json")
	settingsJson, err := json.Marshal(expectedSettings)
	assert.NoError(t, err)

	assert.NotNil(t, settingsFileStat)
	assert.Equal(t, settingsFileStat.FileType, fakesys.FakeFileTypeFile)
	assert.Equal(t, settingsFileStat.Content, string(settingsJson))
	assert.Equal(t, settingsService.GetAgentId(), "123-456-789")
}

func TestRunDoesNotFetchSettingsIfTheyAreOnTheDisk(t *testing.T) {
	infSettings := boshsettings.Settings{AgentId: "xxx-xxx-xxx"}
	expectedSettings := boshsettings.Settings{AgentId: "123-456-789"}

	fakeInfrastructure, fakePlatform, dirProvider := getBootstrapDependencies()
	fakeInfrastructure.Settings = infSettings

	existingSettingsBytes, _ := json.Marshal(expectedSettings)
	fakePlatform.GetFs().WriteToFile("/var/vcap/bosh/settings.json", string(existingSettingsBytes))

	boot := New(fakeInfrastructure, fakePlatform, dirProvider)
	settingsService, err := boot.Run()
	assert.NoError(t, err)

	settingsFileStat := fakePlatform.Fs.GetFileTestStat(dirProvider.BaseDir() + "/bosh/settings.json")

	assert.NotNil(t, settingsFileStat)
	assert.Equal(t, settingsFileStat.FileType, fakesys.FakeFileTypeFile)
	assert.Equal(t, settingsFileStat.Content, string(existingSettingsBytes))
	assert.Equal(t, settingsService.GetAgentId(), "123-456-789")
}

func TestRunSetsUpHostname(t *testing.T) {
	fakeInfrastructure, fakePlatform, dirProvider := getBootstrapDependencies()
	fakeInfrastructure.Settings = boshsettings.Settings{
		AgentId: "foo-bar-baz-123",
	}

	boot := New(fakeInfrastructure, fakePlatform, dirProvider)
	boot.Run()

	assert.Equal(t, fakePlatform.SetupHostnameHostname, "foo-bar-baz-123")
}

func TestRunSetsUpNetworking(t *testing.T) {
	settings := boshsettings.Settings{
		Networks: boshsettings.Networks{
			"bosh": boshsettings.Network{},
		},
	}

	fakeInfrastructure, fakePlatform, dirProvider := getBootstrapDependencies()
	fakeInfrastructure.Settings = settings

	boot := New(fakeInfrastructure, fakePlatform, dirProvider)
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

	fakeInfrastructure, fakePlatform, dirProvider := getBootstrapDependencies()
	fakeInfrastructure.Settings = settings

	boot := New(fakeInfrastructure, fakePlatform, dirProvider)
	boot.Run()

	assert.Equal(t, fakePlatform.SetupEphemeralDiskWithPathDevicePath, "/dev/sda")
}

func TestRunMountsPersistentDisk(t *testing.T) {
	settings := boshsettings.Settings{
		Disks: boshsettings.Disks{
			Persistent: map[string]string{"vol-123": "/dev/sdb"},
		},
	}

	fakeInfrastructure, fakePlatform, dirProvider := getBootstrapDependencies()
	fakeInfrastructure.Settings = settings

	boot := New(fakeInfrastructure, fakePlatform, dirProvider)
	_, err := boot.Run()

	assert.NoError(t, err)
	assert.Equal(t, fakePlatform.MountPersistentDiskDevicePath, "/dev/sdb")
	assert.Equal(t, fakePlatform.MountPersistentDiskMountPoint, dirProvider.StoreDir())
}

func TestRunErrorsIfThereIsMoreThanOnePersistentDisk(t *testing.T) {
	settings := boshsettings.Settings{
		Disks: boshsettings.Disks{
			Persistent: map[string]string{
				"vol-123": "/dev/sdb",
				"vol-456": "/dev/sdc",
			},
		},
	}

	fakeInfrastructure, fakePlatform, dirProvider := getBootstrapDependencies()
	fakeInfrastructure.Settings = settings

	boot := New(fakeInfrastructure, fakePlatform, dirProvider)
	_, err := boot.Run()

	assert.Error(t, err)
}

func TestRunDoesNotTryToMountWhenNoPersistentDisk(t *testing.T) {
	settings := boshsettings.Settings{
		Disks: boshsettings.Disks{
			Persistent: map[string]string{},
		},
	}

	fakeInfrastructure, fakePlatform, dirProvider := getBootstrapDependencies()
	fakeInfrastructure.Settings = settings

	boot := New(fakeInfrastructure, fakePlatform, dirProvider)
	_, err := boot.Run()

	assert.NoError(t, err)
	assert.Equal(t, fakePlatform.MountPersistentDiskDevicePath, "")
	assert.Equal(t, fakePlatform.MountPersistentDiskMountPoint, "")
}

func TestRunSetsRootAndVcapPasswords(t *testing.T) {
	fakeInfrastructure, fakePlatform, dirProvider := getBootstrapDependencies()
	fakeInfrastructure.Settings.Env.Bosh.Password = "some-encrypted-password"

	boot := New(fakeInfrastructure, fakePlatform, dirProvider)
	boot.Run()

	assert.Equal(t, 2, len(fakePlatform.UserPasswords))
	assert.Equal(t, "some-encrypted-password", fakePlatform.UserPasswords["root"])
	assert.Equal(t, "some-encrypted-password", fakePlatform.UserPasswords["vcap"])
}

func TestRunDoesNotSetPasswordIfNotProvided(t *testing.T) {
	settings := boshsettings.Settings{}

	fakeInfrastructure, fakePlatform, dirProvider := getBootstrapDependencies()
	fakeInfrastructure.Settings = settings

	boot := New(fakeInfrastructure, fakePlatform, dirProvider)
	boot.Run()

	assert.Equal(t, 0, len(fakePlatform.UserPasswords))
}

func TestRunSetsTime(t *testing.T) {
	fakeInfrastructure, fakePlatform, dirProvider := getBootstrapDependencies()
	fakeInfrastructure.Settings.Ntp = []string{"0.north-america.pool.ntp.org", "1.north-america.pool.ntp.org"}

	boot := New(fakeInfrastructure, fakePlatform, dirProvider)
	boot.Run()

	assert.Equal(t, 2, len(fakePlatform.SetTimeWithNtpServersServers))
	assert.Equal(t, "0.north-america.pool.ntp.org", fakePlatform.SetTimeWithNtpServersServers[0])
	assert.Equal(t, "1.north-america.pool.ntp.org", fakePlatform.SetTimeWithNtpServersServers[1])
}

func TestRunSetupsUpMonitUser(t *testing.T) {
	fakeInfrastructure, fakePlatform, dirProvider := getBootstrapDependencies()
	boot := New(fakeInfrastructure, fakePlatform, dirProvider)

	boot.Run()

	assert.True(t, fakePlatform.SetupMonitUserSetup)
}

func TestRunStartsMonit(t *testing.T) {
	fakeInfrastructure, fakePlatform, dirProvider := getBootstrapDependencies()
	boot := New(fakeInfrastructure, fakePlatform, dirProvider)

	boot.Run()

	assert.True(t, fakePlatform.StartMonitStarted)
}

func getBootstrapDependencies() (inf *fakeinf.FakeInfrastructure, platform *fakeplatform.FakePlatform, dirProvider boshdir.DirectoriesProvider) {
	inf = &fakeinf.FakeInfrastructure{}
	platform = fakeplatform.NewFakePlatform()
	dirProvider = boshdir.NewDirectoriesProvider("/var/vcap")
	return
}
