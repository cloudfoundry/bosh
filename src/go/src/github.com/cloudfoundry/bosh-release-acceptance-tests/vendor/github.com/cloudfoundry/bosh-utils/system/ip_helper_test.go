package system_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	. "github.com/cloudfoundry/bosh-utils/system"
)

func init() {
	Describe("Testing with Ginkgo", func() {
		It("calculate network and broadcast", func() {

			network, broadcast, err := CalculateNetworkAndBroadcast("192.168.195.6", "255.255.255.0")
			Expect(err).ToNot(HaveOccurred())
			Expect(network).To(Equal("192.168.195.0"))
			Expect(broadcast).To(Equal("192.168.195.255"))
		})
		It("calculate network and broadcast errs with bad ip address", func() {

			_, _, err := CalculateNetworkAndBroadcast("192.168.195", "255.255.255.0")
			Expect(err).To(HaveOccurred())
		})
		It("calculate network and broadcast errs with bad netmask", func() {

			_, _, err := CalculateNetworkAndBroadcast("192.168.195.0", "255.255.255")
			Expect(err).To(HaveOccurred())
		})
	})
}
