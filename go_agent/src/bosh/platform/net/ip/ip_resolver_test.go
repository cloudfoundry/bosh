package ip_test

import (
	gonet "net"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	. "bosh/platform/net/ip"
)

type NotIPNet struct{}

func (i NotIPNet) String() string  { return "" }
func (i NotIPNet) Network() string { return "" }

var _ = Describe("ipResolver", func() {
	var (
		ipResolver IPResolver
	)

	BeforeEach(func() {
		ipResolver = NewIPResolver(NetworkInterfaceToAddrsFunc)
	})

	Describe("GetPrimaryIPv4", func() {
		findInterfaceName := func() string {
			if _, err := gonet.InterfaceByName("en0"); err == nil {
				return "en0"
			} else if _, err := gonet.InterfaceByName("eth0"); err == nil {
				return "eth0"
			} else if _, err := gonet.InterfaceByName("venet0"); err == nil {
				// Travis CI uses venet0 as primary network interface
				return "venet0"
			}

			panic("Not sure which interface name to use: en0 and eth0 are not found")
		}

		It("returns primary IPv4 for an interface", func() {
			ip, err := ipResolver.GetPrimaryIPv4(findInterfaceName())
			Expect(err).ToNot(HaveOccurred())

			Expect(ip.IP).ToNot(BeNil())
			Expect(ip.IP).ToNot(Equal(gonet.ParseIP("0.0.0.0")))
		})

		Context("when interface exists", func() {
			var (
				addrs []gonet.Addr
			)

			BeforeEach(func() {
				ifaceToAddrs := func(_ string) ([]gonet.Addr, error) { return addrs, nil }
				ipResolver = NewIPResolver(ifaceToAddrs)
			})

			It("returns first ipv4 address from associated interface", func() {
				addrs = []gonet.Addr{
					NotIPNet{},
					&gonet.IPNet{IP: gonet.IPv6linklocalallrouters},
					&gonet.IPNet{IP: gonet.ParseIP("127.0.0.1"), Mask: gonet.CIDRMask(16, 32)},
					&gonet.IPNet{IP: gonet.ParseIP("127.0.0.10"), Mask: gonet.CIDRMask(24, 32)},
				}

				ip, err := ipResolver.GetPrimaryIPv4("fake-iface-name")
				Expect(err).ToNot(HaveOccurred())
				Expect(ip.String()).To(Equal("127.0.0.1/16"))
			})

			It("returns error if associated interface does not have any addresses", func() {
				addrs = []gonet.Addr{}

				ip, err := ipResolver.GetPrimaryIPv4("fake-iface-name")
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("No addresses found for interface"))
				Expect(ip).To(BeNil())
			})

			It("returns error if associated interface only has non-IPNet addresses", func() {
				addrs = []gonet.Addr{NotIPNet{}}

				ip, err := ipResolver.GetPrimaryIPv4("fake-iface-name")
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("Failed to find primary IPv4 address for interface"))
				Expect(ip).To(BeNil())
			})

			It("returns error if associated interface only has ipv6 addresses", func() {
				addrs = []gonet.Addr{&gonet.IPNet{IP: gonet.IPv6linklocalallrouters}}

				ip, err := ipResolver.GetPrimaryIPv4("fake-iface-name")
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("Failed to find primary IPv4 address for interface"))
				Expect(ip).To(BeNil())
			})
		})

		Context("when interface does not exist", func() {
			// using NetworkInterfaceToAddrsFunc so fake-iface-name is not going to be found

			It("returns error", func() {
				ip, err := ipResolver.GetPrimaryIPv4("fake-iface-name")
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("net: no such interface")) // error comes from net (stdlib)
				Expect(ip).To(BeNil())
			})
		})
	})
})
