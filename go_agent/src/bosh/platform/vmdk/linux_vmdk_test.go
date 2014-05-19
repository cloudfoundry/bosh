package vmdk_test

import (
	boshlog "bosh/logger"
	. "bosh/platform/vmdk"
	fakesys "bosh/system/fakes"
	"errors"
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
)

var _ = Describe("LinuxVmdk", func() {
	var (
		runner *fakesys.FakeCmdRunner
		vmdk   Vmdk
	)

	BeforeEach(func() {
		runner = fakesys.NewFakeCmdRunner()
		logger = boshlog.NewLogger(boshlog.LevelNone)
	})

	JustBeforeEach(func() {
		vmdk = NewLinuxVmdk(runner, logger)
	})

	Describe("Mount", func() {
		var (
			mountResults fakesys.FakeCmdResult
		)

		BeforeEach(func() {
			mountResults = fakesys.FakeCmdResult{}
		})

		JustBeforeEach(func() {
			runner.AddCmdResult("blkid", "/dev/sda1: UUID=\"ac647c11-a380-47c6-8830-a0edf9091fc8\" TYPE=\"ext4\"\n/dev/sdb1: UUID=\"1461ff24-ec2b-4ac7-a9dd-5a6140c5593e\" TYPE=\"swap\"\n/dev/sdc: LABEL=\"CDROM\" TYPE=\"iso9660\"")
			runner.AddCmdResult("mount /dev/sdc /fake/settings/path", mountResults)
		})

		It("runs the mount command", func() {
			err := vmdk.Mount("/fake/settings/path")
			Expect(err).NotTo(HaveOccurred())
			Expect(runner.RunCommands).To(Equal([][]string{{"mount", "/dev/sdc", "/fake/settings/path"}}))
		})

		Context("when mount command errors", func() {
			BeforeEach(func() {
				mountResults = fakesys.FakeCmdResult{
					Stderr: "failed to mount",
					Error:  errors.New("exit 1"),
				}
			})

			It("wraps the error", func() {
				err := vmdk.Mount("/fake/settings/path")
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(Equal("Mounting VMDK: failed to mount: exit 1"))
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
			runner.AddCmdResult("blkid", "/dev/sda1: UUID=\"ac647c11-a380-47c6-8830-a0edf9091fc8\" TYPE=\"ext4\"\n/dev/sdb1: UUID=\"1461ff24-ec2b-4ac7-a9dd-5a6140c5593e\" TYPE=\"swap\"\n/dev/sdc: LABEL=\"CDROM\" TYPE=\"iso9660\"")
			runner.AddCmdResult("umount /dev/sdc", umountResults)
		})

		It("runs the umount command", func() {
			err := vmdk.Unmount()
			Expect(err).NotTo(HaveOccurred())
			Expect(runner.RunCommands).To(Equal([][]string{{"umount", "/dev/sdc"}}))
		})

		Context("when umount command errors", func() {
			BeforeEach(func() {
				umountResults = fakesys.FakeCmdResult{
					Stderr: "failed to umount",
					Error:  errors.New("exit 1"),
				}
			})

			It("wraps the error", func() {
				err := vmdk.Unmount()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(Equal("Unmounting VMDK: failed to umount: exit 1"))
			})
		})
	})
})
