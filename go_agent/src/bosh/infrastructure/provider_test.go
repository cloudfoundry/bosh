package infrastructure_test

import (
	. "bosh/infrastructure"
	boshlog "bosh/logger"
	fakeplatform "bosh/platform/fakes"
	. "github.com/onsi/ginkgo"
	"github.com/stretchr/testify/assert"
)

func getNewProvider() (logger boshlog.Logger, platform *fakeplatform.FakePlatform, provider Provider) {
	platform = fakeplatform.NewFakePlatform()
	logger = boshlog.NewLogger(boshlog.LEVEL_NONE)
	provider = NewProvider(logger, platform)
	return
}
func init() {
	Describe("Testing with Ginkgo", func() {
		It("get returns an aws infrastructure", func() {
			logger, platform, provider := getNewProvider()
			inf, err := provider.Get("aws")

			assert.NoError(GinkgoT(), err)
			assert.IsType(GinkgoT(), NewAwsInfrastructure("http://169.254.169.254", NewDigDnsResolver(logger), platform), inf)
		})
		It("get returns vsphere infrastructure", func() {

			_, platform, provider := getNewProvider()
			inf, err := provider.Get("vsphere")

			assert.NoError(GinkgoT(), err)
			assert.IsType(GinkgoT(), NewVsphereInfrastructure(platform), inf)
		})
		It("get returns an error on unknown infrastructure", func() {

			_, _, provider := getNewProvider()
			_, err := provider.Get("some unknown infrastructure name")

			assert.Error(GinkgoT(), err)
		})
	})
}
