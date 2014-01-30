package system

import (
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestCalculateNetworkAndBroadcast(t *testing.T) {
	network, broadcast, err := CalculateNetworkAndBroadcast("192.168.195.6", "255.255.255.0")
	assert.NoError(t, err)
	assert.Equal(t, network, "192.168.195.0")
	assert.Equal(t, broadcast, "192.168.195.255")
}

func TestCalculateNetworkAndBroadcastErrsWithBadIpAddress(t *testing.T) {
	_, _, err := CalculateNetworkAndBroadcast("192.168.195", "255.255.255.0")
	assert.Error(t, err)
}

func TestCalculateNetworkAndBroadcastErrsWithBadNetmask(t *testing.T) {
	_, _, err := CalculateNetworkAndBroadcast("192.168.195.0", "255.255.255")
	assert.Error(t, err)
}
