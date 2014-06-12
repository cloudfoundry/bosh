package bootstrap_test

import (
	"errors"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	. "bosh/bootstrap"
	fakeinf "bosh/infrastructure/fakes"
	boshlog "bosh/logger"
	fakeplatform "bosh/platform/fakes"
	boshsettings "bosh/settings"
	boshdir "bosh/settings/directories"
	fakesettings "bosh/settings/fakes"
)

func init() {
	Describe("bootstrap", func() {
		Describe("Run", func() {
			var (
				inf         *fakeinf.FakeInfrastructure
				platform    *fakeplatform.FakePlatform
				dirProvider boshdir.DirectoriesProvider

				settingsServiceProvider *fakesettings.FakeSettingsServiceProvider
				settingsService         *fakesettings.FakeSettingsService
			)

			BeforeEach(func() {
				inf = &fakeinf.FakeInfrastructure{
					GetEphemeralDiskPathFound:    true,
					GetEphemeralDiskPathRealPath: "/dev/sdz",
				}
				platform = fakeplatform.NewFakePlatform()
				dirProvider = boshdir.NewDirectoriesProvider("/var/vcap")

				settingsServiceProvider = fakesettings.NewServiceProvider()
				settingsService = settingsServiceProvider.NewServiceSettingsService
			})

			bootstrap := func() (boshsettings.Service, error) {
				logger := boshlog.NewLogger(boshlog.LevelNone)
				return New(inf, platform, dirProvider, settingsServiceProvider, logger).Run()
			}

			It("sets up runtime configuration", func() {
				_, err := bootstrap()
				Expect(err).NotTo(HaveOccurred())
				Expect(platform.SetupRuntimeConfigurationWasInvoked).To(BeTrue())
			})

			It("sets up ssh", func() {
				_, err := bootstrap()
				Expect(err).NotTo(HaveOccurred())
				Expect(inf.SetupSshUsername).To(Equal("vcap"))
			})

			It("sets up hostname", func() {
				settingsService.Settings.AgentID = "foo-bar-baz-123"

				_, err := bootstrap()
				Expect(err).NotTo(HaveOccurred())
				Expect(platform.SetupHostnameHostname).To(Equal("foo-bar-baz-123"))
			})

			It("returns the settings service", func() {
				result, err := bootstrap()
				Expect(err).NotTo(HaveOccurred())
				Expect(result).To(Equal(settingsService))

				Expect(settingsServiceProvider.NewServiceFs).To(Equal(platform.GetFs()))
				Expect(settingsServiceProvider.NewServiceDir).To(Equal(dirProvider.BoshDir()))
				Expect(settingsServiceProvider.NewDefaultNetworkResolver).To(Equal(platform))

				// cannot compare NewServiceFetcher so call it to see that it returns inf settings
				fetchedSettings, err := settingsServiceProvider.NewServiceFetcher()
				Expect(err).NotTo(HaveOccurred())
				Expect(fetchedSettings).To(Equal(inf.Settings))
			})

			It("fetches initial settings", func() {
				_, err := bootstrap()
				Expect(err).NotTo(HaveOccurred())
				Expect(settingsService.SettingsWereLoaded).To(BeTrue())
			})

			It("returns error from loading initial settings", func() {
				settingsService.LoadSettingsError = errors.New("fake-load-error")

				_, err := bootstrap()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("fake-load-error"))
			})

			It("sets up networking", func() {
				networks := boshsettings.Networks{
					"bosh": boshsettings.Network{},
				}
				settingsService.Settings.Networks = networks

				_, err := bootstrap()
				Expect(err).NotTo(HaveOccurred())
				Expect(inf.SetupNetworkingNetworks).To(Equal(networks))
			})

			It("sets up ephemeral disk", func() {
				settingsService.Settings.Disks = boshsettings.Disks{
					Ephemeral: "fake-ephemeral-disk-setting",
				}

				inf.GetEphemeralDiskPathRealPath = "/dev/sda"
				inf.GetEphemeralDiskPathFound = true

				_, err := bootstrap()
				Expect(err).NotTo(HaveOccurred())
				Expect(platform.SetupEphemeralDiskWithPathDevicePath).To(Equal("/dev/sda"))
				Expect(inf.GetEphemeralDiskPathDevicePath).To(Equal("fake-ephemeral-disk-setting"))
			})

			It("returns error if setting ephemeral disk fails", func() {
				platform.SetupEphemeralDiskWithPathErr = errors.New("fake-setup-ephemeral-disk-err")
				_, err := bootstrap()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("fake-setup-ephemeral-disk-err"))
			})

			It("sets up data dir", func() {
				_, err := bootstrap()
				Expect(err).NotTo(HaveOccurred())
				Expect(platform.SetupDataDirCalled).To(BeTrue())
			})

			It("returns error if set up of data dir fails", func() {
				platform.SetupDataDirErr = errors.New("fake-setup-data-dir-err")
				_, err := bootstrap()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("fake-setup-data-dir-err"))
			})

			It("sets up tmp dir", func() {
				_, err := bootstrap()
				Expect(err).NotTo(HaveOccurred())
				Expect(platform.SetupTmpDirCalled).To(BeTrue())
			})

			It("returns error if set up of tmp dir fails", func() {
				platform.SetupTmpDirErr = errors.New("fake-setup-tmp-dir-err")
				_, err := bootstrap()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("fake-setup-tmp-dir-err"))
			})

			It("mounts persistent disk", func() {
				settingsService.Settings.Disks = boshsettings.Disks{
					Persistent: map[string]string{"vol-123": "/dev/sdb"},
				}

				_, err := bootstrap()
				Expect(err).NotTo(HaveOccurred())
				Expect(platform.MountPersistentDiskDevicePath).To(Equal("/dev/sdb"))
				Expect(platform.MountPersistentDiskMountPoint).To(Equal(dirProvider.StoreDir()))
			})

			It("errors if there is more than one persistent disk", func() {
				settingsService.Settings.Disks = boshsettings.Disks{
					Persistent: map[string]string{
						"vol-123": "/dev/sdb",
						"vol-456": "/dev/sdc",
					},
				}

				_, err := bootstrap()
				Expect(err).To(HaveOccurred())
			})

			It("does not try to mount when no persistent disk", func() {
				settingsService.Settings.Disks = boshsettings.Disks{
					Persistent: map[string]string{},
				}

				_, err := bootstrap()
				Expect(err).NotTo(HaveOccurred())
				Expect(platform.MountPersistentDiskDevicePath).To(Equal(""))
				Expect(platform.MountPersistentDiskMountPoint).To(Equal(""))
			})

			It("sets root and vcap passwords", func() {
				settingsService.Settings.Env.Bosh.Password = "some-encrypted-password"

				_, err := bootstrap()
				Expect(err).NotTo(HaveOccurred())
				Expect(2).To(Equal(len(platform.UserPasswords)))
				Expect("some-encrypted-password").To(Equal(platform.UserPasswords["root"]))
				Expect("some-encrypted-password").To(Equal(platform.UserPasswords["vcap"]))
			})

			It("does not set password if not provided", func() {
				_, err := bootstrap()
				Expect(err).NotTo(HaveOccurred())
				Expect(0).To(Equal(len(platform.UserPasswords)))
			})

			It("sets ntp", func() {
				settingsService.Settings.Ntp = []string{
					"0.north-america.pool.ntp.org",
					"1.north-america.pool.ntp.org",
				}

				_, err := bootstrap()
				Expect(err).NotTo(HaveOccurred())
				Expect(2).To(Equal(len(platform.SetTimeWithNtpServersServers)))
				Expect("0.north-america.pool.ntp.org").To(Equal(platform.SetTimeWithNtpServersServers[0]))
				Expect("1.north-america.pool.ntp.org").To(Equal(platform.SetTimeWithNtpServersServers[1]))
			})

			It("setups up monit user", func() {
				_, err := bootstrap()
				Expect(err).NotTo(HaveOccurred())
				Expect(platform.SetupMonitUserSetup).To(BeTrue())
			})

			It("starts monit", func() {
				_, err := bootstrap()
				Expect(err).NotTo(HaveOccurred())
				Expect(platform.StartMonitStarted).To(BeTrue())
			})
		})
	})
}
