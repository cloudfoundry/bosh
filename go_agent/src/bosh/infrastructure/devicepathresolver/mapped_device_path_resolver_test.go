package devicepathresolver_test

import (
	"time"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	. "bosh/infrastructure/devicepathresolver"
	boshsys "bosh/system"
	fakesys "bosh/system/fakes"
)

var _ = Describe("mappedDevicePathResolver", func() {
	var (
		fs       boshsys.FileSystem
		resolver DevicePathResolver
	)

	BeforeEach(func() {
		fs = fakesys.NewFakeFileSystem()
		resolver = NewMappedDevicePathResolver(time.Second, fs)
	})

	Context("when a matching /dev/xvdX device is found", func() {
		BeforeEach(func() {
			fs.WriteFile("/dev/xvda", []byte{})
			fs.WriteFile("/dev/vda", []byte{})
			fs.WriteFile("/dev/sda", []byte{})
		})

		It("returns the match", func() {
			realPath, err := resolver.GetRealDevicePath("/dev/sda")
			Expect(err).NotTo(HaveOccurred())
			Expect(realPath).To(Equal("/dev/xvda"))
		})
	})

	Context("when a matching /dev/vdX device is found", func() {
		BeforeEach(func() {
			fs.WriteFile("/dev/vda", []byte{})
			fs.WriteFile("/dev/sda", []byte{})
		})

		It("returns the match", func() {
			realPath, err := resolver.GetRealDevicePath("/dev/sda")
			Expect(err).NotTo(HaveOccurred())
			Expect(realPath).To(Equal("/dev/vda"))
		})
	})

	Context("when a matching /dev/sdX device is found", func() {
		BeforeEach(func() {
			fs.WriteFile("/dev/sda", []byte{})
		})

		It("returns the match", func() {
			realPath, err := resolver.GetRealDevicePath("/dev/sda")
			Expect(err).NotTo(HaveOccurred())
			Expect(realPath).To(Equal("/dev/sda"))
		})
	})

	Context("when no matching device is found the first time", func() {
		Context("when the timeout has not expired", func() {
			BeforeEach(func() {
				time.AfterFunc(time.Second, func() {
					fs.WriteFile("/dev/xvda", []byte{})
				})
			})

			It("returns the match", func() {
				realPath, err := resolver.GetRealDevicePath("/dev/sda")
				Expect(err).NotTo(HaveOccurred())
				Expect(realPath).To(Equal("/dev/xvda"))
			})
		})

		Context("when the timeout has expired", func() {
			It("errs", func() {
				_, err := resolver.GetRealDevicePath("/dev/sda")
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(Equal("Timed out getting real device path for /dev/sda"))
			})
		})
	})

	Context("when an invalid device name is passed in", func() {
		It("panics", func() {
			Expect(func() {
				resolver.GetRealDevicePath("not even a device")
			}).To(Panic())
		})
	})
})
