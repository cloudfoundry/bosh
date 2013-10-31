package infrastructure

import (
	"github.com/stretchr/testify/assert"
	"net"
	"testing"
)

func TestLookupHostWithAValidHost(t *testing.T) {
	res := digDnsResolver{}
	ip, err := res.LookupHost([]string{"8.8.8.8"}, "google.com.")

	assert.NoError(t, err)
	assert.NotNil(t, net.ParseIP(ip))
}

func TestLookupHostWithMultipleDnsServers(t *testing.T) {
	res := digDnsResolver{}
	ip, err := res.LookupHost([]string{"127.0.0.127", "8.8.8.8"}, "google.com.")

	assert.NoError(t, err)
	assert.NotNil(t, net.ParseIP(ip))
}

func TestLookupHostAnUnknownHost(t *testing.T) {
	res := digDnsResolver{}
	_, err := res.LookupHost([]string{"8.8.8.8"}, "google.com.local.")

	assert.Error(t, err)
}
