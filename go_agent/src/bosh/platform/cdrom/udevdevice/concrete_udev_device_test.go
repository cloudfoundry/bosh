package udevdevice_test

import (
	. "bosh/platform/cdrom/udevdevice"
	fakes "bosh/system/fakes"
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
)

var _ = Describe("ConcreteUdevDevice", func() {
	var (
		cmdRunner *fakes.FakeCmdRunner
		udev      ConcreteUdevDevice
	)

	BeforeEach(func() {
		cmdRunner = fakes.NewFakeCmdRunner()
	})

	JustBeforeEach(func() {
		udev = NewConcreteUdevDevice(cmdRunner)
	})

	Describe("#Settle", func() {
		Context("if `udevadm` is a runnable command", func() {
			BeforeEach(func() {
				cmdRunner.AvailableCommands["udevadm"] = true
			})

			It("runs `udevadm settle`", func() {
				err := udev.Settle()
				Expect(err).NotTo(HaveOccurred())
				Expect(len(cmdRunner.RunCommands)).To(Equal(1))
				Expect(cmdRunner.RunCommands[0]).To(Equal([]string{"udevadm", "settle"}))
			})
		})

		Context("if `udevsettle` is a runnable command", func() {
			BeforeEach(func() {
				cmdRunner.AvailableCommands["udevsettle"] = true
			})

			It("runs `udevsettle`", func() {
				err := udev.Settle()
				Expect(err).NotTo(HaveOccurred())
				Expect(len(cmdRunner.RunCommands)).To(Equal(1))
				Expect(cmdRunner.RunCommands[0]).To(Equal([]string{"udevsettle"}))
			})
		})

		Context("if neither `udevadm` nor `udevsettle` exist", func() {
			It("errors", func() {
				err := udev.Settle()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(Equal("can not find udevadm or udevsettle commands"))
			})
		})
	})
})
