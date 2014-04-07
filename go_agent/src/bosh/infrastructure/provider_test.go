package infrastructure_test

import (
	"time"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
	"github.com/stretchr/testify/assert"

	. "bosh/infrastructure"
	boshdevicepathresolver "bosh/infrastructure/device_path_resolver"
	boshlog "bosh/logger"
	fakeplatform "bosh/platform/fakes"
)

func getNewProvider() (logger boshlog.Logger, platform *fakeplatform.FakePlatform, provider Provider) {
	platform = fakeplatform.NewFakePlatform()
	logger = boshlog.NewLogger(boshlog.LevelNone)
	provider = NewProvider(logger, platform)
	return
}
func init() {
	Describe("Testing with Ginkgo", func() {
		It("get returns an aws infrastructure", func() {
			logger, platform, provider := getNewProvider()
			inf, err := provider.Get("aws")

			devicePathResolver := boshdevicepathresolver.NewAwsDevicePathResolver(500*time.Millisecond, platform.GetFs())

			Expect(err).ToNot(HaveOccurred())
			assert.IsType(GinkgoT(), NewAwsInfrastructure("http://169.254.169.254", NewDigDNSResolver(logger), platform, devicePathResolver), inf)
		})
		It("get returns vsphere infrastructure", func() {

			logger, platform, provider := getNewProvider()
			inf, err := provider.Get("vsphere")

			devicePathResolver := boshdevicepathresolver.NewAwsDevicePathResolver(500*time.Millisecond, platform.GetFs())

			Expect(err).ToNot(HaveOccurred())
			assert.IsType(GinkgoT(), NewVsphereInfrastructure(platform, devicePathResolver, logger), inf)
		})
		It("get returns an error on unknown infrastructure", func() {

			_, _, provider := getNewProvider()
			_, err := provider.Get("some unknown infrastructure name")

			Expect(err).To(HaveOccurred())
		})
	})
}
