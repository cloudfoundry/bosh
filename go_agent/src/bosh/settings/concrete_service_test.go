package settings

import (
	"errors"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestRefresh(t *testing.T) {
	var fetcher = func() (settings Settings, err error) {
		settings = Settings{AgentId: "some-new-agent-id"}
		return
	}

	settings := Settings{AgentId: "some-agent-id"}
	service := NewService(settings, fetcher)
	err := service.Refresh()

	assert.NoError(t, err)
	assert.Equal(t, service.GetAgentId(), "some-new-agent-id")
}

func TestRefreshOnError(t *testing.T) {
	var fetcher = func() (settings Settings, err error) {
		settings = Settings{AgentId: "some-new-agent-id"}
		err = errors.New("Error fetching settings!")
		return
	}

	settings := Settings{AgentId: "some-old-agent-id"}
	service := NewService(settings, fetcher)
	err := service.Refresh()

	assert.Error(t, err)
	assert.Contains(t, err.Error(), "Error fetching settings!")
	assert.Equal(t, service.GetAgentId(), "some-old-agent-id")
}

func TestGetAgentId(t *testing.T) {
	settings := Settings{AgentId: "some-agent-id"}
	assert.Equal(t, NewService(settings, nil).GetAgentId(), "some-agent-id")
}

func TestGetVm(t *testing.T) {
	vm := Vm{Name: "some-vm-id"}
	settings := Settings{Vm: vm}
	assert.Equal(t, NewService(settings, nil).GetVm(), vm)
}

func TestGetMbusUrl(t *testing.T) {
	settings := Settings{Mbus: "nats://user:pwd@some-ip:some-port"}
	assert.Equal(t, NewService(settings, nil).GetMbusUrl(), "nats://user:pwd@some-ip:some-port")
}

func TestGetDisks(t *testing.T) {
	disks := Disks{System: "foo", Ephemeral: "bar"}
	settings := Settings{Disks: disks}
	assert.Equal(t, NewService(settings, nil).GetDisks(), disks)
}

func TestGetDefaultIp(t *testing.T) {
	networks := Networks{
		"bosh": Network{Ip: "xx.xx.xx.xx"},
	}
	settings := Settings{Networks: networks}
	ip, found := NewService(settings, nil).GetDefaultIp()
	assert.True(t, found)
	assert.Equal(t, ip, "xx.xx.xx.xx")
}

func TestGetIps(t *testing.T) {
	networks := Networks{
		"bosh":  Network{Ip: "xx.xx.xx.xx"},
		"vip":   Network{Ip: "zz.zz.zz.zz"},
		"other": Network{},
	}
	settings := Settings{Networks: networks}
	ips := NewService(settings, nil).GetIps()
	assert.Equal(t, ips, []string{"xx.xx.xx.xx", "zz.zz.zz.zz"})
}
