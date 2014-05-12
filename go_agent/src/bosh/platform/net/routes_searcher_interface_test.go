package net_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	. "bosh/platform/net"
)

var _ = Describe("Route", func() {
	Describe("IsDefault", func() {
		It("returns true if destination is 0.0.0.0", func() {
			Expect(Route{Destination: "0.0.0.0"}.IsDefault()).To(BeTrue())
		})

		It("returns false if destination is not 0.0.0.0", func() {
			Expect(Route{}.IsDefault()).To(BeFalse())
			Expect(Route{Destination: "1.1.1.1"}.IsDefault()).To(BeFalse())
		})
	})
})
