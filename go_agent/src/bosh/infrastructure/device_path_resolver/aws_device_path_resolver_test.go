package device_path_resolver

import (
	boshsys "bosh/system"
	fakesys "bosh/system/fakes"
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
	"time"
)

var _ = Describe("Path Resolver", func() {
	var (
		fs       boshsys.FileSystem
		resolver DevicePathResolver
	)

	BeforeEach(func() {
		fs = fakesys.NewFakeFileSystem()
		resolver = NewAwsDevicePathResolver(time.Second, fs)
	})

	Context("When a matching /dev/xvdX device is found", func() {
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

	Context("When a matching /dev/vdX device is found", func() {
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

	Context("When a matching /dev/sdX device is found", func() {
		BeforeEach(func() {
			fs.WriteFile("/dev/sda", []byte{})
		})

		It("returns the match", func() {
			realPath, err := resolver.GetRealDevicePath("/dev/sda")
			Expect(err).NotTo(HaveOccurred())
			Expect(realPath).To(Equal("/dev/sda"))
		})
	})

	Context("When no matching device is found the first time", func() {
		Context("When the timeout has not expired", func() {
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

		Context("When the timeout has expired", func() {
			It("errs", func() {
				_, err := resolver.GetRealDevicePath("/dev/sda")
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(Equal("Timed out getting real device path for /dev/sda"))
			})
		})

	})

	Context("When an invalid device name is passed in", func() {
		It("panics", func() {
			wrapper := func() {
				resolver.GetRealDevicePath("not even a device")
			}
			Expect(wrapper).To(Panic())
		})
	})
})
