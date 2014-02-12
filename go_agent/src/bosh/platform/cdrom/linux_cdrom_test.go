package cdrom_test

import (
	. "bosh/platform/cdrom"
	fakeudev "bosh/platform/cdrom/udevdevice/fakes"
	"errors"
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
)

var _ = Describe("LinuxCdrom", func() {
	Describe("#WaitForMedia", func() {
		var (
			udev *fakeudev.FakeUdevDevice
			cd   Cdrom
		)

		BeforeEach(func() {
			udev = fakeudev.NewFakeUdevDevice()
		})

		JustBeforeEach(func() {
			cd = NewLinuxCdrom(udev)
		})

		It("polls the cdrom to force udev to notice it", func() {
			err := cd.WaitForMedia()
			Expect(err).NotTo(HaveOccurred())
			Expect(udev.KickDeviceFile).To(Equal("/dev/sr0"))
		})

		It("waits for udev to settle outstanding kernel events", func() {
			err := cd.WaitForMedia()
			Expect(err).NotTo(HaveOccurred())
			Expect(udev.Settled).To(Equal(true))
		})

		It("ensures that device is readable after a few seconds", func() {
			err := cd.WaitForMedia()
			Expect(err).NotTo(HaveOccurred())
			Expect(udev.EnsureDeviceReadableFile).To(Equal("/dev/sr0"))
		})

		Context("if cdrom is not readable after a few seconds", func() {
			BeforeEach(func() {
				udev.EnsureDeviceReadableError = errors.New("oops")
			})

			It("returns an error", func() {
				err := cd.WaitForMedia()
				Expect(err).To(HaveOccurred())
			})
		})

	})
})
