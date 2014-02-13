package cdrom_test

import (
	. "bosh/platform/cdrom"
	fakeudev "bosh/platform/cdrom/udevdevice/fakes"
	fakesys "bosh/system/fakes"
	"errors"
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
)

var _ = Describe("LinuxCdrom", func() {
	var (
		udev   *fakeudev.FakeUdevDevice
		runner *fakesys.FakeCmdRunner
		cd     Cdrom
	)

	BeforeEach(func() {
		udev = fakeudev.NewFakeUdevDevice()
		runner = fakesys.NewFakeCmdRunner()
	})

	JustBeforeEach(func() {
		cd = NewLinuxCdrom("/dev/sr0", udev, runner)
	})

	Describe("WaitForMedia", func() {
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

	Describe("Mount", func() {
		var (
			mountResults fakesys.FakeCmdResult
		)

		BeforeEach(func() {
			mountResults = fakesys.FakeCmdResult{}
		})

		JustBeforeEach(func() {
			runner.AddCmdResult("mount /dev/sr0 /fake/settings/path", mountResults)
		})

		It("runs the mount command", func() {
			err := cd.Mount("/fake/settings/path")
			Expect(err).NotTo(HaveOccurred())
			Expect(runner.RunCommands).To(Equal([][]string{{"mount", "/dev/sr0", "/fake/settings/path"}}))
		})

		Context("when mount command errors", func() {
			BeforeEach(func() {
				mountResults = fakesys.FakeCmdResult{
					Stderr: "failed to mount",
					Error:  errors.New("exit 1"),
				}
			})

			It("wraps the error", func() {
				err := cd.Mount("/fake/settings/path")
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(Equal("Mounting CDROM: failed to mount: exit 1"))
			})
		})
	})

	Describe("Unmount", func() {
		var (
			umountResults fakesys.FakeCmdResult
		)

		BeforeEach(func() {
			umountResults = fakesys.FakeCmdResult{}
		})

		JustBeforeEach(func() {
			runner.AddCmdResult("umount /dev/sr0", umountResults)
		})

		It("runs the umount command", func() {
			err := cd.Unmount()
			Expect(err).NotTo(HaveOccurred())
			Expect(runner.RunCommands).To(Equal([][]string{{"umount", "/dev/sr0"}}))
		})

		Context("when umount command errors", func() {
			BeforeEach(func() {
				umountResults = fakesys.FakeCmdResult{
					Stderr: "failed to umount",
					Error:  errors.New("exit 1"),
				}
			})

			It("wraps the error", func() {
				err := cd.Unmount()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(Equal("Unmounting CDROM: failed to umount: exit 1"))
			})
		})
	})

	Describe("Eject", func() {
		var (
			ejectResults fakesys.FakeCmdResult
		)

		BeforeEach(func() {
			ejectResults = fakesys.FakeCmdResult{}
		})

		JustBeforeEach(func() {
			runner.AddCmdResult("eject /dev/sr0", ejectResults)
		})

		It("runs the mount command", func() {
			err := cd.Eject()
			Expect(err).NotTo(HaveOccurred())
			Expect(runner.RunCommands).To(Equal([][]string{{"eject", "/dev/sr0"}}))
		})

		Context("when mount command errors", func() {
			BeforeEach(func() {
				ejectResults = fakesys.FakeCmdResult{
					Stderr: "failed to eject",
					Error:  errors.New("exit 1"),
				}
			})

			It("wraps the error", func() {
				err := cd.Eject()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(Equal("Ejecting CDROM: failed to eject: exit 1"))
			})
		})
	})
})
