package devicepathresolver_test

import (
	"time"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	. "bosh/infrastructure/devicepathresolver"
	fakesys "bosh/system/fakes"
)

var _ = Describe("VSphere Path Resolver", func() {
	var (
		fs       *fakesys.FakeFileSystem
		resolver DevicePathResolver
	)

	const sleepInterval = time.Millisecond * 1

	BeforeEach(func() {
		fs = fakesys.NewFakeFileSystem()
		resolver = NewVsphereDevicePathResolver(sleepInterval, fs)

		fs.SetGlob("/sys/bus/scsi/devices/*:0:0:0/block/*", []string{
			"/sys/bus/scsi/devices/0:0:0:0/block/sr0",
			"/sys/bus/scsi/devices/6:0:0:0/block/sdd",
			"/sys/bus/scsi/devices/fake-host-id:0:0:0/block/sda",
		})

		fs.SetGlob("/sys/bus/scsi/devices/fake-host-id:0:fake-disk-id:0/block/*", []string{
			"/sys/bus/scsi/devices/fake-host-id:0:fake-disk-id:0/block/sdf",
		})
	})

	Describe("GetRealDevicePath", func() {
		It("rescans the devices attached to the root disks scsi controller", func() {
			resolver.GetRealDevicePath("fake-disk-id")

			scanContents, err := fs.ReadFileString("/sys/class/scsi_host/hostfake-host-id/scan")
			Expect(err).NotTo(HaveOccurred())
			Expect(scanContents).To(Equal("- - -"))
		})

		It("detects device", func() {
			devicePath, err := resolver.GetRealDevicePath("fake-disk-id")
			Expect(err).NotTo(HaveOccurred())
			Expect(devicePath).To(Equal("/dev/sdf"))
		})

		Context("when device does not immediately appear", func() {
			It("retries detection of device", func() {
				fs.SetGlob("/sys/bus/scsi/devices/fake-host-id:0:fake-disk-id:0/block/*",
					[]string{},
					[]string{},
					[]string{},
					[]string{},
					[]string{},
					[]string{"/sys/bus/scsi/devices/fake-host-id:0:fake-disk-id:0/block/sdf"},
				)

				startTime := time.Now()
				devicePath, err := resolver.GetRealDevicePath("fake-disk-id")
				runningTime := time.Since(startTime)
				Expect(err).NotTo(HaveOccurred())
				Expect(runningTime >= sleepInterval).To(BeTrue())
				Expect(devicePath).To(Equal("/dev/sdf"))
			})
		})

		Context("when device is found", func() {
			It("does not retry detection of device", func() {
				fs.SetGlob("/sys/bus/scsi/devices/fake-host-id:0:fake-disk-id:0/block/*",
					[]string{"/sys/bus/scsi/devices/fake-host-id:0:fake-disk-id:0/block/sdf"},
					[]string{},
					[]string{},
					[]string{},
					[]string{},
					[]string{"/sys/bus/scsi/devices/fake-host-id:0:fake-disk-id:0/block/bla"},
				)

				devicePath, err := resolver.GetRealDevicePath("fake-disk-id")
				Expect(err).NotTo(HaveOccurred())
				Expect(devicePath).To(Equal("/dev/sdf"))
			})
		})

		Context("when device never appears", func() {
			It("returns not err", func() {
				fs.SetGlob("/sys/bus/scsi/devices/fake-host-id:0:fake-disk-id:0/block/*", []string{})
				_, err := resolver.GetRealDevicePath("fake-disk-id")
				Expect(err).NotTo(HaveOccurred())
			})
		})
	})
})
