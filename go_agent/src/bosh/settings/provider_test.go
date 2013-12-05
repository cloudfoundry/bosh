package settings

import (
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestGetAgentId(t *testing.T) {
	settings := Settings{AgentId: "some-agent-id"}
	assert.Equal(t, NewProvider(settings).GetAgentId(), "some-agent-id")
}

func TestGetVm(t *testing.T) {
	vm := Vm{Name: "some-vm-id"}
	settings := Settings{Vm: vm}
	assert.Equal(t, NewProvider(settings).GetVm(), vm)
}

func TestGetMbusUrl(t *testing.T) {
	settings := Settings{Mbus: "nats://user:pwd@some-ip:some-port"}
	assert.Equal(t, NewProvider(settings).GetMbusUrl(), "nats://user:pwd@some-ip:some-port")
}

func TestGetDisks(t *testing.T) {
	disks := Disks{System: "foo", Ephemeral: "bar"}
	settings := Settings{Disks: disks}
	assert.Equal(t, NewProvider(settings).GetDisks(), disks)
}

func TestGetDefaultIp(t *testing.T) {
	networks := Networks{
		"bosh": Network{Ip: "xx.xx.xx.xx"},
	}
	settings := Settings{Networks: networks}
	ip, found := NewProvider(settings).GetDefaultIp()
	assert.True(t, found)
	assert.Equal(t, ip, "xx.xx.xx.xx")
}
