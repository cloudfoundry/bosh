package infrastructure_test

import (
	. "bosh/infrastructure"
	boshlog "bosh/logger"
	. "github.com/onsi/ginkgo"
	"github.com/stretchr/testify/assert"
	"net"
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

			assert.NoError(GinkgoT(), err)
			assert.NotNil(GinkgoT(), net.ParseIP(ip))
		})
		It("lookup host with an i p", func() {

			res := createResolver()
			ip, err := res.LookupHost([]string{"8.8.8.8"}, "74.125.239.101")

			assert.NoError(GinkgoT(), err)
			assert.Equal(GinkgoT(), ip, "74.125.239.101")
		})
		It("lookup host with multiple dns servers", func() {

			res := createResolver()
			ip, err := res.LookupHost([]string{"127.0.0.127", "8.8.8.8"}, "google.com.")

			assert.NoError(GinkgoT(), err)
			assert.NotNil(GinkgoT(), net.ParseIP(ip))
		})
		It("lookup host an unknown host", func() {

			res := createResolver()
			_, err := res.LookupHost([]string{"8.8.8.8"}, "google.com.local.")

			assert.Error(GinkgoT(), err)
		})
	})
}
