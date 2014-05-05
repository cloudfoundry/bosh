package infrastructure_test

import (
	"time"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	. "bosh/infrastructure"
	boshdpresolv "bosh/infrastructure/devicepathresolver"
	boshlog "bosh/logger"
	fakeplatform "bosh/platform/fakes"
)

var _ = Describe("Provider", func() {
	var (
		logger   boshlog.Logger
		platform *fakeplatform.FakePlatform
		provider Provider
	)

	BeforeEach(func() {
		platform = fakeplatform.NewFakePlatform()
		logger = boshlog.NewLogger(boshlog.LevelNone)
		provider = NewProvider(logger, platform)
	})

	Describe("Get", func() {
		It("returns aws infrastructure", func() {
			metadataService := NewConcreteMetadataService(
				"http://169.254.169.254",
				NewDigDNSResolver(logger),
			)

			registry := NewConcreteRegistry(metadataService, false)

			expectedDevicePathResolver := boshdpresolv.NewMappedDevicePathResolver(
				500*time.Millisecond,
				platform.GetFs(),
			)

			expectedInf := NewAwsInfrastructure(
				metadataService,
				registry,
				platform,
				expectedDevicePathResolver,
				logger,
			)

			inf, err := provider.Get("aws")
			Expect(err).ToNot(HaveOccurred())
			Expect(inf).To(Equal(expectedInf))
		})

		It("returns openstack infrastructure", func() {
			metadataService := NewConcreteMetadataService(
				"http://169.254.169.254",
				NewDigDNSResolver(logger),
			)

			registry := NewConcreteRegistry(metadataService, true)

			expectedDevicePathResolver := boshdpresolv.NewMappedDevicePathResolver(
				500*time.Millisecond,
				platform.GetFs(),
			)

			expectedInf := NewOpenstackInfrastructure(
				metadataService,
				registry,
				platform,
				expectedDevicePathResolver,
				logger,
			)

			inf, err := provider.Get("openstack")
			Expect(err).ToNot(HaveOccurred())
			Expect(inf).To(Equal(expectedInf))
		})

		It("returns vsphere infrastructure", func() {
			expectedDevicePathResolver := boshdpresolv.NewVsphereDevicePathResolver(
				500*time.Millisecond,
				platform.GetFs(),
			)

			expectedInf := NewVsphereInfrastructure(platform, expectedDevicePathResolver, logger)

			inf, err := provider.Get("vsphere")
			Expect(err).ToNot(HaveOccurred())
			Expect(inf).To(Equal(expectedInf))
		})

		It("returns dummy infrastructure", func() {
			expectedDevicePathResolver := boshdpresolv.NewDummyDevicePathResolver()

			expectedInf := NewDummyInfrastructure(
				platform.GetFs(),
				platform.GetDirProvider(),
				platform,
				expectedDevicePathResolver,
			)

			inf, err := provider.Get("dummy")
			Expect(err).ToNot(HaveOccurred())
			Expect(inf).To(Equal(expectedInf))
		})

		It("returns warden infrastructure", func() {
			expectedDevicePathResolver := boshdpresolv.NewDummyDevicePathResolver()

			expectedInf := NewWardenInfrastructure(
				platform.GetDirProvider(),
				platform,
				expectedDevicePathResolver,
			)

			inf, err := provider.Get("warden")
			Expect(err).ToNot(HaveOccurred())
			Expect(inf).To(Equal(expectedInf))
		})

		It("returns an error on unknown infrastructure", func() {
			_, err := provider.Get("some unknown infrastructure name")
			Expect(err).To(HaveOccurred())
		})
	})
})
