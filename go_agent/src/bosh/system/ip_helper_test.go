package system_test

import (
	. "bosh/system"
	. "github.com/onsi/ginkgo"
	"github.com/stretchr/testify/assert"
)

func init() {
	Describe("Testing with Ginkgo", func() {
		It("calculate network and broadcast", func() {

			network, broadcast, err := CalculateNetworkAndBroadcast("192.168.195.6", "255.255.255.0")
			assert.NoError(GinkgoT(), err)
			assert.Equal(GinkgoT(), network, "192.168.195.0")
			assert.Equal(GinkgoT(), broadcast, "192.168.195.255")
		})
		It("calculate network and broadcast errs with bad ip address", func() {

			_, _, err := CalculateNetworkAndBroadcast("192.168.195", "255.255.255.0")
			assert.Error(GinkgoT(), err)
		})
		It("calculate network and broadcast errs with bad netmask", func() {

			_, _, err := CalculateNetworkAndBroadcast("192.168.195.0", "255.255.255")
			assert.Error(GinkgoT(), err)
		})
	})
}
