package ip_test

import (
	"errors"
	gonet "net"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	. "bosh/platform/net/ip"
	fakeip "bosh/platform/net/ip/fakes"
)

var _ = Describe("resolvingInterfaceAddress", func() {
	var (
		ipResolver       *fakeip.FakeIPResolver
		interfaceAddress InterfaceAddress
	)

	BeforeEach(func() {
		ipResolver = &fakeip.FakeIPResolver{}
		interfaceAddress = NewResolvingInterfaceAddress("fake-iface-name", ipResolver)
	})

	Describe("GetIP", func() {
		Context("when IP was not yet resolved", func() {
			BeforeEach(func() {
				ipResolver.GetPrimaryIPv4IPNet = &gonet.IPNet{
					IP:   gonet.ParseIP("127.0.0.1"),
					Mask: gonet.CIDRMask(16, 32),
				}
			})

			It("resolves the IP", func() {
				ip, err := interfaceAddress.GetIP()
				Expect(err).ToNot(HaveOccurred())
				Expect(ip).To(Equal("127.0.0.1"))

				Expect(ipResolver.GetPrimaryIPv4InterfaceName).To(Equal("fake-iface-name"))
			})

			It("returns error if resolving IP fails", func() {
				ipResolver.GetPrimaryIPv4Err = errors.New("fake-get-primary-ipv4-err")

				ip, err := interfaceAddress.GetIP()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("fake-get-primary-ipv4-err"))
				Expect(ip).To(Equal(""))
			})
		})

		Context("when IP was already resolved", func() {
			BeforeEach(func() {
				ipResolver.GetPrimaryIPv4IPNet = &gonet.IPNet{
					IP:   gonet.ParseIP("127.0.0.1"),
					Mask: gonet.CIDRMask(16, 32),
				}

				_, err := interfaceAddress.GetIP()
				Expect(err).ToNot(HaveOccurred())
			})

			It("does not attempt to resolve IP again", func() {
				ipResolver.GetPrimaryIPv4InterfaceName = ""

				ip, err := interfaceAddress.GetIP()
				Expect(err).ToNot(HaveOccurred())
				Expect(ip).To(Equal("127.0.0.1"))

				Expect(ipResolver.GetPrimaryIPv4InterfaceName).To(Equal(""))
			})
		})
	})
})
