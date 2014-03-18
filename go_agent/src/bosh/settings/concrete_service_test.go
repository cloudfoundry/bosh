package settings_test

import (
	"encoding/json"
	"errors"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	. "bosh/settings"
	fakesys "bosh/system/fakes"
)

func buildService(fetcher SettingsFetcher) (Service, *fakesys.FakeFileSystem) {
	fs := fakesys.NewFakeFileSystem()
	service := NewService(fs, "/setting/path", fetcher)
	return service, fs
}

func buildServiceWithInitialSettings(initialSettings Settings) Service {
	service, _ := buildService(func() (Settings, error) { return initialSettings, nil })
	service.Refresh()
	return service
}

func init() {
	Describe("concreteServiceProvider", func() {
		Describe("NewService", func() {
			It("returns service with settings.json as its settings path", func() {
				// Cannot compare fetcher functions since function comparison is problematic
				fs := fakesys.NewFakeFileSystem()
				service := NewServiceProvider().NewService(fs, "/setting/path", nil)
				Expect(service).To(Equal(NewService(fs, "/setting/path/settings.json", nil)))
			})
		})
	})

	Describe("concreteService", func() {
		itUpdatesSettingsViaFetcher := func(caller func(Service) error) {
			fetchedSettings := Settings{AgentId: "some-new-agent-id"}
			fetcher := func() (Settings, error) { return fetchedSettings, nil }

			It("updates the service with settings from the fetcher", func() {
				service, _ := buildService(fetcher)

				err := caller(service)
				Expect(err).NotTo(HaveOccurred())
				Expect(service.GetAgentId()).To(Equal("some-new-agent-id"))
			})

			It("returns any error from the fetcher", func() {
				service, _ := buildService(
					func() (Settings, error) {
						return Settings{AgentId: "some-agent-id"}, errors.New("Error fetching settings!")
					},
				)

				err := caller(service)
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("Error fetching settings!"))

				Expect(service.GetSettings()).To(Equal(Settings{}))
			})

			It("persists settings to the settings file", func() {
				service, fs := buildService(fetcher)

				err := caller(service)
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

				err := caller(service)
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("fs-write-file-error"))
			})
		}

		Describe("Refresh", func() {
			itUpdatesSettingsViaFetcher(func(service Service) error { return service.Refresh() })
		})

		Describe("FetchInitial", func() {
			Context("when a settings file exists", func() {
				It("returns settings from the settings file", func() {
					service, fs := buildService(nil)

					expectedSettings := Settings{AgentId: "some-agent-id"}
					fs.WriteFile("/setting/path", []byte(`{"agent_id":"some-agent-id"}`))

					err := service.FetchInitial()
					Expect(err).ToNot(HaveOccurred())
					Expect(service.GetSettings()).To(Equal(expectedSettings))
				})
			})

			Context("when no settings file exists", func() {
				itUpdatesSettingsViaFetcher(func(service Service) error { return service.FetchInitial() })
			})
		})

		Describe("ForceNextFetchInitialToRefresh", func() {
			It("removes the settings file", func() {
				service, fs := buildService(nil)

				fs.WriteFile("/setting/path", []byte(`{}`))

				err := service.ForceNextFetchInitialToRefresh()
				Expect(err).ToNot(HaveOccurred())

				Expect(fs.FileExists("/setting/path")).To(BeFalse())
			})

			It("returns err if removing settings file errored", func() {
				service, fs := buildService(nil)

				fs.RemoveAllError = errors.New("fs-remove-all-error")

				err := service.ForceNextFetchInitialToRefresh()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("fs-remove-all-error"))
			})
		})

		Describe("GetSettings", func() {
			It("returns settings", func() {
				settings := Settings{AgentId: "some-agent-id"}
				service := buildServiceWithInitialSettings(settings)
				Expect(service.GetSettings()).To(Equal(settings))
			})
		})

		Describe("GetAgentId", func() {
			It("returns agent id", func() {
				service := buildServiceWithInitialSettings(Settings{AgentId: "some-agent-id"})
				Expect(service.GetAgentId()).To(Equal("some-agent-id"))
			})
		})

		Describe("GetVm", func() {
			It("returns vm", func() {
				vm := Vm{Name: "some-vm-id"}
				service := buildServiceWithInitialSettings(Settings{Vm: vm})
				Expect(service.GetVm()).To(Equal(vm))
			})
		})

		Describe("GetMbusUrl", func() {
			It("returns mbus url", func() {
				service := buildServiceWithInitialSettings(Settings{Mbus: "nats://user:pwd@some-ip:some-port"})
				Expect(service.GetMbusUrl()).To(Equal("nats://user:pwd@some-ip:some-port"))
			})
		})

		Describe("GetDisks", func() {
			It("returns disks", func() {
				disks := Disks{System: "foo", Ephemeral: "bar"}
				service := buildServiceWithInitialSettings(Settings{Disks: disks})
				Expect(service.GetDisks()).To(Equal(disks))
			})
		})

		Describe("GetDefaultIp", func() {
			It("returns default ip", func() {
				networks := Networks{
					"bosh": Network{Ip: "xx.xx.xx.xx"},
				}
				service := buildServiceWithInitialSettings(Settings{Networks: networks})

				ip, found := service.GetDefaultIp()
				Expect(found).To(BeTrue())
				Expect(ip).To(Equal("xx.xx.xx.xx"))
			})
		})

		Describe("GetIps", func() {
			It("returns ips", func() {
				networks := Networks{
					"bosh":  Network{Ip: "xx.xx.xx.xx"},
					"vip":   Network{Ip: "zz.zz.zz.zz"},
					"other": Network{},
				}
				service := buildServiceWithInitialSettings(Settings{Networks: networks})
				Expect(service.GetIps()).To(Equal([]string{"xx.xx.xx.xx", "zz.zz.zz.zz"}))
			})
		})
	})
}
