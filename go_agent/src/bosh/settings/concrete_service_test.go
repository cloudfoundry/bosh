package settings_test

import (
	. "bosh/settings"
	"errors"
	. "github.com/onsi/ginkgo"
	"github.com/stretchr/testify/assert"
)

func init() {
	Describe("Testing with Ginkgo", func() {
		It("refresh", func() {

			var fetcher = func() (settings Settings, err error) {
				settings = Settings{AgentId: "some-new-agent-id"}
				return
			}

			settings := Settings{AgentId: "some-agent-id"}
			service := NewService(settings, fetcher)
			err := service.Refresh()

			assert.NoError(GinkgoT(), err)
			assert.Equal(GinkgoT(), service.GetAgentId(), "some-new-agent-id")
		})
		It("refresh on error", func() {

			var fetcher = func() (settings Settings, err error) {
				settings = Settings{AgentId: "some-new-agent-id"}
				err = errors.New("Error fetching settings!")
				return
			}

			settings := Settings{AgentId: "some-old-agent-id"}
			service := NewService(settings, fetcher)
			err := service.Refresh()

			assert.Error(GinkgoT(), err)
			assert.Contains(GinkgoT(), err.Error(), "Error fetching settings!")
			assert.Equal(GinkgoT(), service.GetAgentId(), "some-old-agent-id")
		})
		It("get agent id", func() {

			settings := Settings{AgentId: "some-agent-id"}
			assert.Equal(GinkgoT(), NewService(settings, nil).GetAgentId(), "some-agent-id")
		})
		It("get vm", func() {

			vm := Vm{Name: "some-vm-id"}
			settings := Settings{Vm: vm}
			assert.Equal(GinkgoT(), NewService(settings, nil).GetVm(), vm)
		})
		It("get mbus url", func() {

			settings := Settings{Mbus: "nats://user:pwd@some-ip:some-port"}
			assert.Equal(GinkgoT(), NewService(settings, nil).GetMbusUrl(), "nats://user:pwd@some-ip:some-port")
		})
		It("get disks", func() {

			disks := Disks{System: "foo", Ephemeral: "bar"}
			settings := Settings{Disks: disks}
			assert.Equal(GinkgoT(), NewService(settings, nil).GetDisks(), disks)
		})
		It("get default ip", func() {

			networks := Networks{
				"bosh": Network{Ip: "xx.xx.xx.xx"},
			}
			settings := Settings{Networks: networks}
			ip, found := NewService(settings, nil).GetDefaultIp()
			assert.True(GinkgoT(), found)
			assert.Equal(GinkgoT(), ip, "xx.xx.xx.xx")
		})
		It("get ips", func() {

			networks := Networks{
				"bosh":  Network{Ip: "xx.xx.xx.xx"},
				"vip":   Network{Ip: "zz.zz.zz.zz"},
				"other": Network{},
			}
			settings := Settings{Networks: networks}
			ips := NewService(settings, nil).GetIps()
			assert.Equal(GinkgoT(), ips, []string{"xx.xx.xx.xx", "zz.zz.zz.zz"})
		})
	})
}
