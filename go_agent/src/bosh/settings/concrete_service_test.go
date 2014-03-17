package settings_test

import (
	"encoding/json"
	"errors"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	. "bosh/settings"
	fakesys "bosh/system/fakes"
)

func buildService(initialSettings Settings, fetcher SettingsFetcher) (Service, *fakesys.FakeFileSystem) {
	fs := fakesys.NewFakeFileSystem()
	service := NewService(fs, "/setting/path", initialSettings, fetcher)
	return service, fs
}

func init() {
	Describe("concreteService", func() {
		Describe("Refresh", func() {
			fetchedSettings := Settings{AgentId: "some-new-agent-id"}
			fetcher := func() (Settings, error) { return fetchedSettings, nil }

			It("updates the service with settings from the fetcher", func() {
				service, _ := buildService(Settings{AgentId: "some-agent-id"}, fetcher)

				err := service.Refresh()
				Expect(err).NotTo(HaveOccurred())
				Expect(service.GetAgentId()).To(Equal("some-new-agent-id"))
			})

			It("returns any error from the fetcher", func() {
				service, _ := buildService(
					Settings{AgentId: "some-old-agent-id"},
					func() (Settings, error) {
						return Settings{}, errors.New("Error fetching settings!")
					},
				)

				err := service.Refresh()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("Error fetching settings!"))

				Expect(service.GetAgentId()).To(Equal("some-old-agent-id"))
			})

			It("persists settings to the settings file", func() {
				service, fs := buildService(Settings{AgentId: "some-agent-id"}, fetcher)

				err := service.Refresh()
				Expect(err).NotTo(HaveOccurred())

				json, err := json.Marshal(fetchedSettings)
				Expect(err).NotTo(HaveOccurred())

				fileContent, err := fs.ReadFile("/setting/path")
				Expect(err).NotTo(HaveOccurred())
				Expect(fileContent).To(Equal(json))
			})

			It("returns any error from writing to the setting file", func() {
				service, fs := buildService(Settings{AgentId: "some-agent-id"}, fetcher)

				fs.WriteToFileError = errors.New("fs-write-file-error")

				err := service.Refresh()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("fs-write-file-error"))
			})
		})

		Describe("GetAgentId", func() {
			It("returns agent id", func() {
				service, _ := buildService(Settings{AgentId: "some-agent-id"}, nil)
				Expect(service.GetAgentId()).To(Equal("some-agent-id"))
			})
		})

		Describe("GetVm", func() {
			It("returns vm", func() {
				vm := Vm{Name: "some-vm-id"}
				service, _ := buildService(Settings{Vm: vm}, nil)
				Expect(service.GetVm()).To(Equal(vm))
			})
		})

		Describe("GetMbusUrl", func() {
			It("returns mbus url", func() {
				service, _ := buildService(Settings{Mbus: "nats://user:pwd@some-ip:some-port"}, nil)
				Expect(service.GetMbusUrl()).To(Equal("nats://user:pwd@some-ip:some-port"))
			})
		})

		Describe("GetDisks", func() {
			It("returns disks", func() {
				disks := Disks{System: "foo", Ephemeral: "bar"}
				service, _ := buildService(Settings{Disks: disks}, nil)
				Expect(service.GetDisks()).To(Equal(disks))
			})
		})

		Describe("GetDefaultIp", func() {
			It("returns default ip", func() {
				networks := Networks{
					"bosh": Network{Ip: "xx.xx.xx.xx"},
				}
				service, _ := buildService(Settings{Networks: networks}, nil)

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
				service, _ := buildService(Settings{Networks: networks}, nil)
				Expect(service.GetIps()).To(Equal([]string{"xx.xx.xx.xx", "zz.zz.zz.zz"}))
			})
		})
	})
}
