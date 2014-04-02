package infrastructure_test

import (
	"net"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	. "bosh/infrastructure"
	boshlog "bosh/logger"
)

func createResolver() (r DigDnsResolver) {
	r = NewDigDnsResolver(boshlog.NewLogger(boshlog.LEVEL_NONE))
	return
}
func init() {
	Describe("Testing with Ginkgo", func() {
		It("lookup host with a valid host", func() {
			res := createResolver()
			ip, err := res.LookupHost([]string{"8.8.8.8"}, "google.com.")

			Expect(err).ToNot(HaveOccurred())
			Expect(net.ParseIP(ip)).ToNot(BeNil())
		})
		It("lookup host with an i p", func() {

			res := createResolver()
			ip, err := res.LookupHost([]string{"8.8.8.8"}, "74.125.239.101")

			Expect(err).ToNot(HaveOccurred())
			Expect(ip).To(Equal("74.125.239.101"))
		})
		It("lookup host with multiple dns servers", func() {

			res := createResolver()
			ip, err := res.LookupHost([]string{"127.0.0.127", "8.8.8.8"}, "google.com.")

			Expect(err).ToNot(HaveOccurred())
			Expect(net.ParseIP(ip)).ToNot(BeNil())
		})
		It("lookup host an unknown host", func() {

			res := createResolver()
			_, err := res.LookupHost([]string{"8.8.8.8"}, "google.com.local.")

			Expect(err).To(HaveOccurred())
		})
	})
}
