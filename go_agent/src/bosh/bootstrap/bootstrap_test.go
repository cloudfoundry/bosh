package bootstrap_test

import (
	. "bosh/bootstrap"
	fakeinf "bosh/infrastructure/fakes"
	fakeplatform "bosh/platform/fakes"
	boshsettings "bosh/settings"
	boshdir "bosh/settings/directories"
	fakesys "bosh/system/fakes"
	"encoding/json"
	. "github.com/onsi/ginkgo"
	"github.com/stretchr/testify/assert"
)

func getBootstrapDependencies() (inf *fakeinf.FakeInfrastructure, platform *fakeplatform.FakePlatform, dirProvider boshdir.DirectoriesProvider) {
	inf = &fakeinf.FakeInfrastructure{}
	inf.GetEphemeralDiskPathFound = true
	inf.GetEphemeralDiskPathRealPath = "/dev/sdz"
	platform = fakeplatform.NewFakePlatform()
	dirProvider = boshdir.NewDirectoriesProvider("/var/vcap")
	return
}
func init() {
	Describe("Testing with Ginkgo", func() {
		It("run sets up runtime configuration", func() {
			fakeInfrastructure, fakePlatform, dirProvider := getBootstrapDependencies()
			boot := New(fakeInfrastructure, fakePlatform, dirProvider)
			boot.Run()

			assert.True(GinkgoT(), fakePlatform.SetupRuntimeConfigurationWasInvoked)
		})
		It("run sets up ssh", func() {

			fakeInfrastructure, fakePlatform, dirProvider := getBootstrapDependencies()
			boot := New(fakeInfrastructure, fakePlatform, dirProvider)
			boot.Run()

			assert.Equal(GinkgoT(), fakeInfrastructure.SetupSshUsername, "vcap")
		})
		It("run gets settings from the infrastructure", func() {

			expectedSettings := boshsettings.Settings{
				AgentId: "123-456-789",
			}

			fakeInfrastructure, fakePlatform, dirProvider := getBootstrapDependencies()
			fakeInfrastructure.Settings = expectedSettings

			boot := New(fakeInfrastructure, fakePlatform, dirProvider)
			settingsService, err := boot.Run()
			assert.NoError(GinkgoT(), err)

			settingsFileStat := fakePlatform.Fs.GetFileTestStat(dirProvider.BaseDir() + "/bosh/settings.json")
			settingsJson, err := json.Marshal(expectedSettings)
			assert.NoError(GinkgoT(), err)

			assert.NotNil(GinkgoT(), settingsFileStat)
			assert.Equal(GinkgoT(), settingsFileStat.FileType, fakesys.FakeFileTypeFile)
			assert.Equal(GinkgoT(), settingsFileStat.Content, string(settingsJson))
			assert.Equal(GinkgoT(), settingsService.GetAgentId(), "123-456-789")
		})
		It("run does not fetch settings if they are on the disk", func() {

			infSettings := boshsettings.Settings{AgentId: "xxx-xxx-xxx"}
			expectedSettings := boshsettings.Settings{AgentId: "123-456-789"}

			fakeInfrastructure, fakePlatform, dirProvider := getBootstrapDependencies()
			fakeInfrastructure.Settings = infSettings

			existingSettingsBytes, _ := json.Marshal(expectedSettings)
			fakePlatform.GetFs().WriteToFile("/var/vcap/bosh/settings.json", string(existingSettingsBytes))

			boot := New(fakeInfrastructure, fakePlatform, dirProvider)
			settingsService, err := boot.Run()
			assert.NoError(GinkgoT(), err)

			settingsFileStat := fakePlatform.Fs.GetFileTestStat(dirProvider.BaseDir() + "/bosh/settings.json")

			assert.NotNil(GinkgoT(), settingsFileStat)
			assert.Equal(GinkgoT(), settingsFileStat.FileType, fakesys.FakeFileTypeFile)
			assert.Equal(GinkgoT(), settingsFileStat.Content, string(existingSettingsBytes))
			assert.Equal(GinkgoT(), settingsService.GetAgentId(), "123-456-789")
		})
		It("run sets up hostname", func() {

			fakeInfrastructure, fakePlatform, dirProvider := getBootstrapDependencies()
			fakeInfrastructure.Settings = boshsettings.Settings{
				AgentId: "foo-bar-baz-123",
			}

			boot := New(fakeInfrastructure, fakePlatform, dirProvider)
			boot.Run()

			assert.Equal(GinkgoT(), fakePlatform.SetupHostnameHostname, "foo-bar-baz-123")
		})
		It("run sets up networking", func() {

			settings := boshsettings.Settings{
				Networks: boshsettings.Networks{
					"bosh": boshsettings.Network{},
				},
			}

			fakeInfrastructure, fakePlatform, dirProvider := getBootstrapDependencies()
			fakeInfrastructure.Settings = settings

			boot := New(fakeInfrastructure, fakePlatform, dirProvider)
			boot.Run()

			assert.Equal(GinkgoT(), fakeInfrastructure.SetupNetworkingNetworks, settings.Networks)
		})
		It("run sets up ephemeral disk", func() {

			settings := boshsettings.Settings{
				Disks: boshsettings.Disks{
					Ephemeral: "fake-ephemeral-disk-setting",
				},
			}

			fakeInfrastructure, fakePlatform, dirProvider := getBootstrapDependencies()
			fakeInfrastructure.Settings = settings

			fakeInfrastructure.GetEphemeralDiskPathRealPath = "/dev/sda"
			fakeInfrastructure.GetEphemeralDiskPathFound = true

			boot := New(fakeInfrastructure, fakePlatform, dirProvider)
			boot.Run()

			assert.Equal(GinkgoT(), fakePlatform.SetupEphemeralDiskWithPathDevicePath, "/dev/sda")
			assert.Equal(GinkgoT(), fakeInfrastructure.GetEphemeralDiskPathDevicePath, "fake-ephemeral-disk-setting")
		})
		It("run sets up tmp dir", func() {

			fakeInfrastructure, fakePlatform, dirProvider := getBootstrapDependencies()

			boot := New(fakeInfrastructure, fakePlatform, dirProvider)
			boot.Run()

			assert.True(GinkgoT(), fakePlatform.SetupTmpDirCalled)
		})
		It("run mounts persistent disk", func() {

			settings := boshsettings.Settings{
				Disks: boshsettings.Disks{
					Persistent: map[string]string{"vol-123": "/dev/sdb"},
				},
			}

			fakeInfrastructure, fakePlatform, dirProvider := getBootstrapDependencies()
			fakeInfrastructure.Settings = settings

			boot := New(fakeInfrastructure, fakePlatform, dirProvider)
			_, err := boot.Run()

			assert.NoError(GinkgoT(), err)
			assert.Equal(GinkgoT(), fakePlatform.MountPersistentDiskDevicePath, "/dev/sdb")
			assert.Equal(GinkgoT(), fakePlatform.MountPersistentDiskMountPoint, dirProvider.StoreDir())
		})
		It("run errors if there is more than one persistent disk", func() {

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

			assert.Error(GinkgoT(), err)
		})
		It("run does not try to mount when no persistent disk", func() {

			settings := boshsettings.Settings{
				Disks: boshsettings.Disks{
					Persistent: map[string]string{},
				},
			}

			fakeInfrastructure, fakePlatform, dirProvider := getBootstrapDependencies()
			fakeInfrastructure.Settings = settings

			boot := New(fakeInfrastructure, fakePlatform, dirProvider)
			_, err := boot.Run()

			assert.NoError(GinkgoT(), err)
			assert.Equal(GinkgoT(), fakePlatform.MountPersistentDiskDevicePath, "")
			assert.Equal(GinkgoT(), fakePlatform.MountPersistentDiskMountPoint, "")
		})
		It("run sets root and vcap passwords", func() {

			fakeInfrastructure, fakePlatform, dirProvider := getBootstrapDependencies()
			fakeInfrastructure.Settings.Env.Bosh.Password = "some-encrypted-password"

			boot := New(fakeInfrastructure, fakePlatform, dirProvider)
			boot.Run()

			assert.Equal(GinkgoT(), 2, len(fakePlatform.UserPasswords))
			assert.Equal(GinkgoT(), "some-encrypted-password", fakePlatform.UserPasswords["root"])
			assert.Equal(GinkgoT(), "some-encrypted-password", fakePlatform.UserPasswords["vcap"])
		})
		It("run does not set password if not provided", func() {

			settings := boshsettings.Settings{}

			fakeInfrastructure, fakePlatform, dirProvider := getBootstrapDependencies()
			fakeInfrastructure.Settings = settings

			boot := New(fakeInfrastructure, fakePlatform, dirProvider)
			boot.Run()

			assert.Equal(GinkgoT(), 0, len(fakePlatform.UserPasswords))
		})
		It("run sets time", func() {

			fakeInfrastructure, fakePlatform, dirProvider := getBootstrapDependencies()
			fakeInfrastructure.Settings.Ntp = []string{"0.north-america.pool.ntp.org", "1.north-america.pool.ntp.org"}

			boot := New(fakeInfrastructure, fakePlatform, dirProvider)
			boot.Run()

			assert.Equal(GinkgoT(), 2, len(fakePlatform.SetTimeWithNtpServersServers))
			assert.Equal(GinkgoT(), "0.north-america.pool.ntp.org", fakePlatform.SetTimeWithNtpServersServers[0])
			assert.Equal(GinkgoT(), "1.north-america.pool.ntp.org", fakePlatform.SetTimeWithNtpServersServers[1])
		})
		It("run setups up monit user", func() {

			fakeInfrastructure, fakePlatform, dirProvider := getBootstrapDependencies()
			boot := New(fakeInfrastructure, fakePlatform, dirProvider)

			boot.Run()

			assert.True(GinkgoT(), fakePlatform.SetupMonitUserSetup)
		})
		It("run starts monit", func() {

			fakeInfrastructure, fakePlatform, dirProvider := getBootstrapDependencies()
			boot := New(fakeInfrastructure, fakePlatform, dirProvider)

			boot.Run()

			assert.True(GinkgoT(), fakePlatform.StartMonitStarted)
		})
	})
}
