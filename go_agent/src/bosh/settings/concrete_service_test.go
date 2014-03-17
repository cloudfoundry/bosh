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
	Describe("concreteService", func() {
		Describe("Refresh", func() {
			fetchedSettings := Settings{AgentId: "some-new-agent-id"}
			fetcher := func() (Settings, error) { return fetchedSettings, nil }

			It("updates the service with settings from the fetcher", func() {
				service, _ := buildService(fetcher)

				err := service.Refresh()
				Expect(err).NotTo(HaveOccurred())
				Expect(service.GetAgentId()).To(Equal("some-new-agent-id"))
			})

			It("returns any error from the fetcher", func() {
				service, _ := buildService(
					func() (Settings, error) {
						return Settings{AgentId: "some-agent-id"}, errors.New("Error fetching settings!")
					},
				)

				err := service.Refresh()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("Error fetching settings!"))

				Expect(service.GetSettings()).To(Equal(Settings{}))
			})

			It("persists settings to the settings file", func() {
				service, fs := buildService(fetcher)

				err := service.Refresh()
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

				err := service.Refresh()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("fs-write-file-error"))
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
