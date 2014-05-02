package infrastructure_test

import (
	"net"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	. "bosh/infrastructure"
	boshlog "bosh/logger"
)

var _ = Describe("DigDNSResolver", func() {
	var (
		resolver DigDNSResolver
	)

	BeforeEach(func() {
		logger := boshlog.NewLogger(boshlog.LevelNone)
		resolver = NewDigDNSResolver(logger)
	})

	Describe("LookupHost", func() {
		Context("when host is an ip", func() {
			It("lookup host with an ip", func() {
				ip, err := resolver.LookupHost([]string{"8.8.8.8"}, "74.125.239.101")
				Expect(err).ToNot(HaveOccurred())
				Expect(ip).To(Equal("74.125.239.101"))
			})
		})

		Context("when host is not an ip", func() {
			It("retursns ip for resolved host", func() {
				ip, err := resolver.LookupHost([]string{"8.8.8.8"}, "google.com.")
				Expect(err).ToNot(HaveOccurred())
				Expect(net.ParseIP(ip)).ToNot(BeNil())
			})

			It("returns ip for resolved host after failing and then succeeding", func() {
				ip, err := resolver.LookupHost([]string{"127.0.0.127", "8.8.8.8"}, "google.com.")
				Expect(err).ToNot(HaveOccurred())
				Expect(net.ParseIP(ip)).ToNot(BeNil())
			})

			It("returns error if there are 0 dns servers", func() {
				ip, err := resolver.LookupHost([]string{}, "google.com.")
				Expect(err).To(MatchError("No DNS servers provided"))
				Expect(ip).To(BeEmpty())
			})

			It("returns error if all dns servers cannot resolve it", func() {
				ip, err := resolver.LookupHost([]string{"8.8.8.8"}, "google.com.local.")
				Expect(err).To(HaveOccurred())
				Expect(ip).To(BeEmpty())
			})
		})
	})
})
