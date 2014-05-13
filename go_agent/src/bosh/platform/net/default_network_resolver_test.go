package net_test

import (
	"errors"
	gonet "net"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	. "bosh/platform/net"
	fakenet "bosh/platform/net/fakes"
	boshsettings "bosh/settings"
)

type NotIPNet struct{}

func (i NotIPNet) String() string  { return "" }
func (i NotIPNet) Network() string { return "" }

var _ = Describe("defaultNetworkResolver", func() {
	var (
		routesSearcher *fakenet.FakeRoutesSearcher
		resolver       DefaultNetworkResolver
	)

	BeforeEach(func() {
		routesSearcher = &fakenet.FakeRoutesSearcher{}
		resolver = NewDefaultNetworkResolver(routesSearcher, DefaultInterfaceToAddrsFunc)
	})

	Describe("Resolve", func() {
		It("returns a network associated with a first default gateway", func() {
			var ifaceName string

			if _, err := gonet.InterfaceByName("en0"); err == nil {
				ifaceName = "en0"
			} else if _, err := gonet.InterfaceByName("eth0"); err == nil {
				ifaceName = "eth0"
			} else if _, err := gonet.InterfaceByName("venet0"); err == nil {
				// Travis CI uses venet0 as primary network interface
				ifaceName = "venet0"
			} else {
				panic("Not sure which interface name to use: en0 and eth0 are not found")
			}

			routesSearcher.SearchRoutesRoutes = []Route{
				Route{
					Destination:   "fake-route1-dest",
					Gateway:       "fake-route1-gateway",
					InterfaceName: "fake-route1-iface",
				},
				Route{
					Destination:   "0.0.0.0",
					Gateway:       "fake-route2-gateway",
					InterfaceName: ifaceName,
				},
			}

			network, err := resolver.GetDefaultNetwork()
			Expect(err).ToNot(HaveOccurred())

			ip := gonet.ParseIP(network.IP)
			Expect(ip).ToNot(BeNil())
			Expect(ip).ToNot(Equal(gonet.ParseIP("0.0.0.0")))

			netmask := gonet.ParseIP(network.Netmask)
			Expect(netmask).ToNot(BeNil())
			Expect(netmask).ToNot(Equal(gonet.ParseIP("0.0.0.0")))

			Expect(network.Gateway).To(Equal("fake-route2-gateway"))
		})

		It("returns error if searching routes fails", func() {
			routesSearcher.SearchRoutesErr = errors.New("fake-search-routes-err")

			network, err := resolver.GetDefaultNetwork()
			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(ContainSubstring("fake-search-routes-err"))
			Expect(network).To(Equal(boshsettings.Network{}))
		})

		Context("when default route is found", func() {
			BeforeEach(func() {
				routesSearcher.SearchRoutesRoutes = []Route{
					Route{
						Destination:   "0.0.0.0",
						Gateway:       "fake-gateway",
						InterfaceName: "fake-interface-name",
					},
				}
			})

			Context("when interface associated with found route cannot be found", func() {
				var (
					addrs []gonet.Addr
				)

				BeforeEach(func() {
					resolver = NewDefaultNetworkResolver(
						routesSearcher,
						func(_ string) ([]gonet.Addr, error) { return addrs, nil },
					)
				})

				It("returns first ipv4 address from associated interface", func() {
					addrs = []gonet.Addr{
						NotIPNet{},
						&gonet.IPNet{IP: gonet.IPv6linklocalallrouters},
						&gonet.IPNet{IP: gonet.ParseIP("127.0.0.1"), Mask: gonet.CIDRMask(16, 32)},
						&gonet.IPNet{IP: gonet.ParseIP("127.0.0.10"), Mask: gonet.CIDRMask(24, 32)},
					}

					network, err := resolver.GetDefaultNetwork()
					Expect(err).ToNot(HaveOccurred())
					Expect(network).To(Equal(boshsettings.Network{
						IP:      "127.0.0.1",
						Netmask: "255.255.0.0",
						Gateway: "fake-gateway",
					}))
				})

				It("returns error if associated interface does not have any addresses", func() {
					addrs = []gonet.Addr{}

					network, err := resolver.GetDefaultNetwork()
					Expect(err).To(HaveOccurred())
					Expect(err.Error()).To(ContainSubstring("No addresses"))
					Expect(network).To(Equal(boshsettings.Network{}))
				})

				It("returns error if associated interface only has non-IPNet addresses", func() {
					addrs = []gonet.Addr{NotIPNet{}}

					network, err := resolver.GetDefaultNetwork()
					Expect(err).To(HaveOccurred())
					Expect(err.Error()).To(ContainSubstring("Failed to find IPv4 address"))
					Expect(network).To(Equal(boshsettings.Network{}))
				})

				It("returns error if associated interface only has ipv6 addresses", func() {
					addrs = []gonet.Addr{&gonet.IPNet{IP: gonet.IPv6linklocalallrouters}}

					network, err := resolver.GetDefaultNetwork()
					Expect(err).To(HaveOccurred())
					Expect(err.Error()).To(ContainSubstring("Failed to find IPv4 address"))
					Expect(network).To(Equal(boshsettings.Network{}))
				})
			})

			Context("when interface associated with found route cannot be found", func() {
				// using default InterfaceToAddrsFunc so fake-interface-name is not going to be found

				It("returns error", func() {
					network, err := resolver.GetDefaultNetwork()
					Expect(err).To(HaveOccurred())
					Expect(err.Error()).To(ContainSubstring("fake-interface-name: net: no such interface"))
					Expect(network).To(Equal(boshsettings.Network{}))
				})
			})
		})

		Context("when default route is found", func() {
			BeforeEach(func() {
				routesSearcher.SearchRoutesRoutes = []Route{
					Route{Destination: "fake-route-dest"},
				}
			})

			It("returns error", func() {
				network, err := resolver.GetDefaultNetwork()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("Failed to find default route"))
				Expect(network).To(Equal(boshsettings.Network{}))
			})
		})

		Context("when there are no routes", func() {
			BeforeEach(func() {
				routesSearcher.SearchRoutesRoutes = []Route{}
			})

			It("returns error if there are no routes", func() {
				network, err := resolver.GetDefaultNetwork()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("No routes"))
				Expect(network).To(Equal(boshsettings.Network{}))
			})
		})
	})
})
