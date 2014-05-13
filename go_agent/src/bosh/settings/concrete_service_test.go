package settings_test

import (
	"encoding/json"
	"errors"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	boshlog "bosh/logger"
	. "bosh/settings"
	fakesys "bosh/system/fakes"
)

func buildService(fetcher SettingsFetcher) (Service, *fakesys.FakeFileSystem) {
	fs := fakesys.NewFakeFileSystem()
	logger := boshlog.NewLogger(boshlog.LevelNone)
	service := NewService(fs, "/setting/path", fetcher, logger)
	return service, fs
}

func buildServiceWithInitialSettings(initialSettings Settings) Service {
	service, _ := buildService(func() (Settings, error) { return initialSettings, nil })

	err := service.LoadSettings()
	Expect(err).NotTo(HaveOccurred())

	return service
}

func init() {
	Describe("concreteServiceProvider", func() {
		Describe("NewService", func() {
			It("returns service with settings.json as its settings path", func() {
				// Cannot compare fetcher functions since function comparison is problematic
				fs := fakesys.NewFakeFileSystem()
				logger := boshlog.NewLogger(boshlog.LevelNone)
				service := NewServiceProvider().NewService(fs, "/setting/path", nil, logger)
				Expect(service).To(Equal(NewService(fs, "/setting/path/settings.json", nil, logger)))
			})
		})
	})

	Describe("concreteService", func() {
		Describe("LoadSettings", func() {
			Context("when settings fetcher succeeds fetching settings", func() {
				fetchedSettings := Settings{AgentID: "some-new-agent-id"}
				fetcher := func() (Settings, error) { return fetchedSettings, nil }

				It("updates the service with settings from the fetcher", func() {
					service, _ := buildService(fetcher)

					err := service.LoadSettings()
					Expect(err).NotTo(HaveOccurred())
					Expect(service.GetAgentID()).To(Equal("some-new-agent-id"))
				})

				It("persists settings to the settings file", func() {
					service, fs := buildService(fetcher)

					err := service.LoadSettings()
					Expect(err).NotTo(HaveOccurred())

					json, err := json.Marshal(fetchedSettings)
					Expect(err).NotTo(HaveOccurred())

					fileContent, err := fs.ReadFile("/setting/path")
					Expect(err).NotTo(HaveOccurred())
					Expect(fileContent).To(Equal(json))
				})

				It("returns any error from writing to the setting file", func() {
					service, fs := buildService(fetcher)

					fs.WriteToFileError = errors.New("fs-write-file-error")

					err := service.LoadSettings()
					Expect(err).To(HaveOccurred())
					Expect(err.Error()).To(ContainSubstring("fs-write-file-error"))
				})
			})

			Context("when settings fetcher fails fetching settings", func() {
				fetcher := func() (Settings, error) { return Settings{}, errors.New("fake-fetch-error") }

				Context("when a settings file exists", func() {
					It("returns settings from the settings file", func() {
						service, fs := buildService(fetcher)

						expectedSettings := Settings{AgentID: "some-agent-id"}
						fs.WriteFile("/setting/path", []byte(`{"agent_id":"some-agent-id"}`))

						err := service.LoadSettings()
						Expect(err).ToNot(HaveOccurred())
						Expect(service.GetSettings()).To(Equal(expectedSettings))
					})
				})

				Context("when no settings file exists", func() {
					It("returns any error from the fetcher", func() {
						service, _ := buildService(fetcher)

						err := service.LoadSettings()
						Expect(err).To(HaveOccurred())
						Expect(err.Error()).To(ContainSubstring("fake-fetch-error"))

						Expect(service.GetSettings()).To(Equal(Settings{}))
					})
				})
			})
		})

		Describe("InvalidateSettings", func() {
			It("removes the settings file", func() {
				service, fs := buildService(nil)

				fs.WriteFile("/setting/path", []byte(`{}`))

				err := service.InvalidateSettings()
				Expect(err).ToNot(HaveOccurred())

				Expect(fs.FileExists("/setting/path")).To(BeFalse())
			})

			It("returns err if removing settings file errored", func() {
				service, fs := buildService(nil)

				fs.RemoveAllError = errors.New("fs-remove-all-error")

				err := service.InvalidateSettings()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("fs-remove-all-error"))
			})
		})

		Describe("GetSettings", func() {
			It("returns settings", func() {
				settings := Settings{AgentID: "some-agent-id"}
				service := buildServiceWithInitialSettings(settings)
				Expect(service.GetSettings()).To(Equal(settings))
			})
		})

		Describe("GetAgentID", func() {
			It("returns agent id", func() {
				service := buildServiceWithInitialSettings(Settings{AgentID: "some-agent-id"})
				Expect(service.GetAgentID()).To(Equal("some-agent-id"))
			})
		})

		Describe("GetVM", func() {
			It("returns vm", func() {
				vm := VM{Name: "some-vm-id"}
				service := buildServiceWithInitialSettings(Settings{VM: vm})
				Expect(service.GetVM()).To(Equal(vm))
			})
		})

		Describe("GetMbusURL", func() {
			It("returns mbus url", func() {
				service := buildServiceWithInitialSettings(Settings{Mbus: "nats://user:pwd@some-ip:some-port"})
				Expect(service.GetMbusURL()).To(Equal("nats://user:pwd@some-ip:some-port"))
			})
		})

		Describe("GetDisks", func() {
			It("returns disks", func() {
				disks := Disks{System: "foo", Ephemeral: "bar"}
				service := buildServiceWithInitialSettings(Settings{Disks: disks})
				Expect(service.GetDisks()).To(Equal(disks))
			})
		})

		Describe("GetDefaultIP", func() {
			It("returns default ip", func() {
				networks := Networks{
					"bosh": Network{IP: "xx.xx.xx.xx"},
				}
				service := buildServiceWithInitialSettings(Settings{Networks: networks})

				ip, found := service.GetDefaultIP()
				Expect(found).To(BeTrue())
				Expect(ip).To(Equal("xx.xx.xx.xx"))
			})
		})

		Describe("GetIPs", func() {
			It("returns ips", func() {
				networks := Networks{
					"bosh":  Network{IP: "xx.xx.xx.xx"},
					"vip":   Network{IP: "zz.zz.zz.zz"},
					"other": Network{},
				}
				service := buildServiceWithInitialSettings(Settings{Networks: networks})
				Expect(service.GetIPs()).To(Equal([]string{"xx.xx.xx.xx", "zz.zz.zz.zz"}))
			})
		})
	})
}
