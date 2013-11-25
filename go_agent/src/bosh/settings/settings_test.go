package settings

import (
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestDefaultNetworkForWhenNetworksIsEmpty(t *testing.T) {
	networks := Networks{}

	_, found := networks.DefaultNetworkFor("dns")
	assert.False(t, found)
}

func TestDefaultNetworkForWithSingleNetwork(t *testing.T) {
	networks := Networks{
		"bosh": NetworkSettings{
			Dns: []string{"xx.xx.xx.xx"},
		},
	}

	settings, found := networks.DefaultNetworkFor("dns")
	assert.True(t, found)
	assert.Equal(t, settings, networks["bosh"])
}

func TestDefaultNetworkForWithMultipleNetworksAndDefaultIsFoundForDns(t *testing.T) {
	networks := Networks{
		"bosh": NetworkSettings{
			Default: []string{"dns"},
			Dns:     []string{"xx.xx.xx.xx", "yy.yy.yy.yy", "zz.zz.zz.zz"},
		},
		"vip": NetworkSettings{
			Default: []string{},
			Dns:     []string{"aa.aa.aa.aa"},
		},
	}

	settings, found := networks.DefaultNetworkFor("dns")
	assert.True(t, found)
	assert.Equal(t, settings, networks["bosh"])
}

func TestDefaultNetworkForWithMultipleNetworksAndDefaultIsNotFound(t *testing.T) {
	networks := Networks{
		"bosh": NetworkSettings{
			Default: []string{"foo"},
			Dns:     []string{"xx.xx.xx.xx", "yy.yy.yy.yy", "zz.zz.zz.zz"},
		},
		"vip": NetworkSettings{
			Default: []string{},
			Dns:     []string{"aa.aa.aa.aa"},
		},
	}

	_, found := networks.DefaultNetworkFor("dns")
	assert.False(t, found)
}

func TestDefaultIpWithTwoNetworks(t *testing.T) {
	networks := Networks{
		"bosh": NetworkSettings{
			Ip: "xx.xx.xx.xx",
		},
		"vip": NetworkSettings{
			Ip: "aa.aa.aa.aa",
		},
	}

	ip, found := networks.DefaultIp()
	assert.True(t, found)
	assert.Equal(t, "xx.xx.xx.xx", ip)
}

func TestDefaultIpWithTwoNetworksOnlyWithDefaults(t *testing.T) {
	networks := Networks{
		"bosh": NetworkSettings{
			Ip: "xx.xx.xx.xx",
		},
		"vip": NetworkSettings{
			Ip:      "aa.aa.aa.aa",
			Default: []string{"dns"},
		},
	}

	ip, found := networks.DefaultIp()
	assert.True(t, found)
	assert.Equal(t, "aa.aa.aa.aa", ip)
}

func TestDefaultIpWhenNoneSpecified(t *testing.T) {
	networks := Networks{
		"bosh": NetworkSettings{},
		"vip": NetworkSettings{
			Default: []string{"dns"},
		},
	}

	_, found := networks.DefaultIp()
	assert.False(t, found)
}
