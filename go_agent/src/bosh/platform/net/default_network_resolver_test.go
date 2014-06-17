package net_test

import (
	"errors"
	gonet "net"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	. "bosh/platform/net"
	fakenet "bosh/platform/net/fakes"
	fakeip "bosh/platform/net/ip/fakes"
	boshsettings "bosh/settings"
)

var _ = Describe("defaultNetworkResolver", func() {
	var (
		routesSearcher *fakenet.FakeRoutesSearcher
		ipResolver     *fakeip.FakeIPResolver
		resolver       DefaultNetworkResolver
	)

	BeforeEach(func() {
		routesSearcher = &fakenet.FakeRoutesSearcher{}
		ipResolver = &fakeip.FakeIPResolver{}
		resolver = NewDefaultNetworkResolver(routesSearcher, ipResolver)
	})

	Describe("Resolve", func() {
		Context("when default route is found", func() {
			BeforeEach(func() {
				routesSearcher.SearchRoutesRoutes = []Route{
					Route{ // non-default route
						Destination:   "non-default-route1-dest",
						Gateway:       "non-default-route1-gateway",
						InterfaceName: "non-default-route1-iface",
					},
					Route{ // route with default destination
						Destination:   "0.0.0.0",
						Gateway:       "fake-gateway",
						InterfaceName: "fake-interface-name",
					},
				}
			})

			Context("when primary IPv4 exists for the found route", func() {
				BeforeEach(func() {
					ipResolver.GetPrimaryIPv4IPNet = &gonet.IPNet{
						IP:   gonet.ParseIP("127.0.0.1"),
						Mask: gonet.CIDRMask(16, 32),
					}
				})

				It("returns network with primary IPv4 address from associated interface", func() {
					network, err := resolver.GetDefaultNetwork()
					Expect(err).ToNot(HaveOccurred())
					Expect(network).To(Equal(boshsettings.Network{
						IP:      "127.0.0.1",
						Netmask: "255.255.0.0",
						Gateway: "fake-gateway",
					}))
				})
			})

			Context("when primary IPv4 does not exist for the found route", func() {
				BeforeEach(func() {
					ipResolver.GetPrimaryIPv4Err = errors.New("fake-get-primary-ipv4-err")
				})

				It("returns error", func() {
					network, err := resolver.GetDefaultNetwork()
					Expect(err).To(HaveOccurred())
					Expect(err.Error()).To(ContainSubstring("fake-get-primary-ipv4-err"))
					Expect(network).To(Equal(boshsettings.Network{}))
				})
			})
		})

		Context("when default route is not found", func() {
			BeforeEach(func() {
				routesSearcher.SearchRoutesRoutes = []Route{
					Route{
						Destination: "non-default-route-dest",
					},
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

		Context("when searching for routes returns error", func() {
			BeforeEach(func() {
				routesSearcher.SearchRoutesErr = errors.New("fake-search-routes-err")
			})

			It("returns error if searching routes fails", func() {
				network, err := resolver.GetDefaultNetwork()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("fake-search-routes-err"))
				Expect(network).To(Equal(boshsettings.Network{}))
			})
		})
	})
})
