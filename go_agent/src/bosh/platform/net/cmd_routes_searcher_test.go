package net_test

import (
	"errors"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	. "bosh/platform/net"
	fakesys "bosh/system/fakes"
)

var _ = Describe("cmdRoutesSeacher", func() {
	var (
		runner   *fakesys.FakeCmdRunner
		searcher RoutesSearcher
	)

	BeforeEach(func() {
		runner = fakesys.NewFakeCmdRunner()
		searcher = NewCmdRoutesSearcher(runner)
	})

	Describe("SearchRoutes", func() {
		Context("when running command succeeds", func() {
			It("returns parsed routes information", func() {
				runner.AddCmdResult("route -n", fakesys.FakeCmdResult{
					Stdout: `Kernel IP routing table
Destination     Gateway         Genmask         Flags Metric Ref    Use Iface
172.16.79.0     0.0.0.0         255.255.255.0   U     0      0        0 eth0
169.254.0.0     0.0.0.0         255.255.0.0     U     1002   0        0 eth0
0.0.0.0         172.16.79.1     0.0.0.0         UG    0      0        0 eth0
`,
				})

				routes, err := searcher.SearchRoutes()
				Expect(err).ToNot(HaveOccurred())
				Expect(routes).To(Equal([]Route{
					Route{Destination: "172.16.79.0", Gateway: "0.0.0.0", InterfaceName: "eth0"},
					Route{Destination: "169.254.0.0", Gateway: "0.0.0.0", InterfaceName: "eth0"},
					Route{Destination: "0.0.0.0", Gateway: "172.16.79.1", InterfaceName: "eth0"},
				}))
			})

			It("ignores empty lines", func() {
				runner.AddCmdResult("route -n", fakesys.FakeCmdResult{
					Stdout: `Kernel IP routing table
Destination     Gateway         Genmask         Flags Metric Ref    Use Iface
`,
				})

				routes, err := searcher.SearchRoutes()
				Expect(err).ToNot(HaveOccurred())
				Expect(routes).To(BeEmpty())
			})
		})

		Context("when running mount command fails", func() {
			It("returns error", func() {
				runner.AddCmdResult("route -n", fakesys.FakeCmdResult{
					Error: errors.New("fake-run-err"),
				})

				routes, err := searcher.SearchRoutes()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("fake-run-err"))
				Expect(routes).To(BeEmpty())
			})
		})
	})
})
