package settings_test

import (
	. "bosh/settings"
	"errors"
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
)

func init() {
	Describe("concreteService", func() {
		Describe("Refresh", func() {
			It("updates the service with settings from the fetcher", func() {
				var fetcher = func() (settings Settings, err error) {
					settings = Settings{AgentId: "some-new-agent-id"}
					return
				}

				settings := Settings{AgentId: "some-agent-id"}
				service := NewService(settings, fetcher)

				err := service.Refresh()
				Expect(err).NotTo(HaveOccurred())
				Expect(service.GetAgentId()).To(Equal("some-new-agent-id"))
			})

			It("returns any error from the fetcher", func() {
				var fetcher = func() (settings Settings, err error) {
					settings = Settings{AgentId: "some-new-agent-id"}
					err = errors.New("Error fetching settings!")
					return
				}

				settings := Settings{AgentId: "some-old-agent-id"}
				service := NewService(settings, fetcher)

				err := service.Refresh()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("Error fetching settings!"))
				Expect(service.GetAgentId()).To(Equal("some-old-agent-id"))
			})
		})

		Describe("GetAgentId", func() {
			It("returns agent id", func() {
				settings := Settings{AgentId: "some-agent-id"}
				Expect(NewService(settings, nil).GetAgentId()).To(Equal("some-agent-id"))
			})
		})

		Describe("GetVm", func() {
			It("returns vm", func() {
				vm := Vm{Name: "some-vm-id"}
				settings := Settings{Vm: vm}
				Expect(NewService(settings, nil).GetVm()).To(Equal(vm))
			})
		})

		Describe("GetMbusUrl", func() {
			It("returns mbus url", func() {
				settings := Settings{Mbus: "nats://user:pwd@some-ip:some-port"}
				Expect(NewService(settings, nil).GetMbusUrl()).To(Equal("nats://user:pwd@some-ip:some-port"))
			})
		})

		Describe("GetDisks", func() {
			It("returns disks", func() {
				disks := Disks{System: "foo", Ephemeral: "bar"}
				settings := Settings{Disks: disks}
				Expect(NewService(settings, nil).GetDisks()).To(Equal(disks))
			})
		})

		Describe("GetDefaultIp", func() {
			It("returns default ip", func() {
				networks := Networks{
					"bosh": Network{Ip: "xx.xx.xx.xx"},
				}
				settings := Settings{Networks: networks}
				ip, found := NewService(settings, nil).GetDefaultIp()
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
				settings := Settings{Networks: networks}
				Expect(NewService(settings, nil).GetIps()).To(Equal([]string{"xx.xx.xx.xx", "zz.zz.zz.zz"}))
			})
		})
	})
}
