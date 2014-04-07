package disk_test

import (
	"errors"
	"time"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	. "bosh/platform/disk"
	fakesys "bosh/system/fakes"
)

type fsWithChangingFile struct {
	procMounts []string
	*fakesys.FakeFileSystem
}

func (fs *fsWithChangingFile) ReadFileString(path string) (content string, err error) {
	if path == "/proc/mounts" {
		content = fs.procMounts[0]
		fs.procMounts = fs.procMounts[1:]
	}
	return
}

const swaponUsageOutput = `Filename				Type		Size	Used	Priority
/dev/swap                              partition	78180316	0	-1
`

const swaponUsageOutputWithOtherDevice = `Filename				Type		Size	Used	Priority
/dev/swap2                              partition	78180316	0	-1
`

func getLinuxMounterDependencies() (runner *fakesys.FakeCmdRunner, fs *fakesys.FakeFileSystem) {
	runner = &fakesys.FakeCmdRunner{}
	fs = &fakesys.FakeFileSystem{}
	return
}
func init() {
	Describe("Testing with Ginkgo", func() {
		It("linux mount", func() {
			runner, fs := getLinuxMounterDependencies()
			fs.WriteFile("/proc/mounts", []byte{})

			mounter := NewLinuxMounter(runner, fs, 1*time.Millisecond)
			err := mounter.Mount("/dev/foo", "/mnt/foo")

			Expect(err).ToNot(HaveOccurred())
			Expect(1).To(Equal(len(runner.RunCommands)))
			Expect(runner.RunCommands[0]).To(Equal([]string{"mount", "/dev/foo", "/mnt/foo"}))
		})
		It("linux mount when disk is already mounted to the good mount point", func() {

			runner, fs := getLinuxMounterDependencies()
			fs.WriteFileString("/proc/mounts", "/dev/foo /mnt/foo\n/dev/bar /mnt/bar")

			mounter := NewLinuxMounter(runner, fs, 1*time.Millisecond)
			err := mounter.Mount("/dev/foo", "/mnt/foo")

			Expect(err).ToNot(HaveOccurred())
			Expect(0).To(Equal(len(runner.RunCommands)))
		})
		It("linux mount when disk is already mounted to the wrong mount point", func() {

			runner, fs := getLinuxMounterDependencies()
			fs.WriteFileString("/proc/mounts", "/dev/foo /mnt/foobarbaz\n/dev/bar /mnt/bar")

			mounter := NewLinuxMounter(runner, fs, 1*time.Millisecond)
			err := mounter.Mount("/dev/foo", "/mnt/foo")

			Expect(err).To(HaveOccurred())
			Expect(0).To(Equal(len(runner.RunCommands)))
		})
		It("linux mount when another disk is already mounted to mount point", func() {

			runner, fs := getLinuxMounterDependencies()
			fs.WriteFileString("/proc/mounts", "/dev/baz /mnt/foo\n/dev/bar /mnt/bar")

			mounter := NewLinuxMounter(runner, fs, 1*time.Millisecond)
			err := mounter.Mount("/dev/foo", "/mnt/foo")

			Expect(err).To(HaveOccurred())
			Expect(0).To(Equal(len(runner.RunCommands)))
		})
		It("remount as readonly", func() {

			runner, fs := getLinuxMounterDependencies()

			procMounts := []string{"/dev/baz /mnt/bar ext4", "/dev/baz /mnt/bar ext4", ""}

			mounter := NewLinuxMounter(runner, &fsWithChangingFile{procMounts, fs}, 1*time.Millisecond)

			err := mounter.RemountAsReadonly("/mnt/bar")

			Expect(err).ToNot(HaveOccurred())
			Expect(2).To(Equal(len(runner.RunCommands)))
			Expect(runner.RunCommands[0]).To(Equal([]string{"umount", "/mnt/bar"}))
			Expect(runner.RunCommands[1]).To(Equal([]string{"mount", "/dev/baz", "/mnt/bar", "-o", "ro"}))
		})
		It("remount", func() {

			runner, fs := getLinuxMounterDependencies()

			procMounts := []string{"/dev/baz /mnt/foo ext4", "/dev/baz /mnt/foo ext4", ""}

			mounter := NewLinuxMounter(runner, &fsWithChangingFile{procMounts, fs}, 1*time.Millisecond)

			err := mounter.Remount("/mnt/foo", "/mnt/bar")

			Expect(err).ToNot(HaveOccurred())
			Expect(2).To(Equal(len(runner.RunCommands)))
			Expect(runner.RunCommands[0]).To(Equal([]string{"umount", "/mnt/foo"}))
			Expect(runner.RunCommands[1]).To(Equal([]string{"mount", "/dev/baz", "/mnt/bar"}))
		})
		It("linux swap on", func() {

			runner, fs := getLinuxMounterDependencies()
			runner.AddCmdResult("swapon -s", fakesys.FakeCmdResult{Stdout: "Filename				Type		Size	Used	Priority\n"})

			mounter := NewLinuxMounter(runner, fs, 1*time.Millisecond)
			mounter.SwapOn("/dev/swap")

			Expect(2).To(Equal(len(runner.RunCommands)))
			Expect(runner.RunCommands[1]).To(Equal([]string{"swapon", "/dev/swap"}))
		})
		It("linux swap on when already on", func() {

			runner, fs := getLinuxMounterDependencies()
			runner.AddCmdResult("swapon -s", fakesys.FakeCmdResult{Stdout: swaponUsageOutput})

			mounter := NewLinuxMounter(runner, fs, 1*time.Millisecond)
			mounter.SwapOn("/dev/swap")
			Expect(1).To(Equal(len(runner.RunCommands)))
			Expect(runner.RunCommands[0]).To(Equal([]string{"swapon", "-s"}))
		})
		It("linux swap on when already on other device", func() {

			runner, fs := getLinuxMounterDependencies()
			runner.AddCmdResult("swapon -s", fakesys.FakeCmdResult{Stdout: swaponUsageOutputWithOtherDevice})

			mounter := NewLinuxMounter(runner, fs, 1*time.Millisecond)
			mounter.SwapOn("/dev/swap")
			Expect(2).To(Equal(len(runner.RunCommands)))
			Expect(runner.RunCommands[0]).To(Equal([]string{"swapon", "-s"}))
			Expect(runner.RunCommands[1]).To(Equal([]string{"swapon", "/dev/swap"}))
		})
		It("linux unmount when partition is mounted", func() {

			runner, fs := getLinuxMounterDependencies()
			fs.WriteFileString("/proc/mounts", "/dev/xvdb2 /var/vcap/data ext4")

			mounter := NewLinuxMounter(runner, fs, 1*time.Millisecond)
			didUnmount, err := mounter.Unmount("/dev/xvdb2")
			Expect(err).ToNot(HaveOccurred())
			Expect(didUnmount).To(BeTrue())

			Expect(1).To(Equal(len(runner.RunCommands)))
			Expect(runner.RunCommands[0]).To(Equal([]string{"umount", "/dev/xvdb2"}))
		})
		It("linux unmount when mount point is mounted", func() {

			runner, fs := getLinuxMounterDependencies()
			fs.WriteFileString("/proc/mounts", "/dev/xvdb2 /var/vcap/data ext4")

			mounter := NewLinuxMounter(runner, fs, 1*time.Millisecond)
			didUnmount, err := mounter.Unmount("/var/vcap/data")
			Expect(err).ToNot(HaveOccurred())
			Expect(didUnmount).To(BeTrue())

			Expect(1).To(Equal(len(runner.RunCommands)))
			Expect(runner.RunCommands[0]).To(Equal([]string{"umount", "/var/vcap/data"}))
		})
		It("linux unmount when partition or mount point is not mounted", func() {

			runner, fs := getLinuxMounterDependencies()
			fs.WriteFileString("/proc/mounts", "/dev/xvdb2 /var/vcap/data ext4")

			mounter := NewLinuxMounter(runner, fs, 1*time.Millisecond)
			didUnmount, err := mounter.Unmount("/dev/xvdb3")
			Expect(err).ToNot(HaveOccurred())
			Expect(didUnmount).To(BeFalse())

			Expect(0).To(Equal(len(runner.RunCommands)))
		})
		It("linux unmount when it fails several times", func() {

			runner, fs := getLinuxMounterDependencies()
			fs.WriteFileString("/proc/mounts", "/dev/xvdb2 /var/vcap/data ext4")

			runner.AddCmdResult("umount /dev/xvdb2", fakesys.FakeCmdResult{Error: errors.New("fake-error")})
			runner.AddCmdResult("umount /dev/xvdb2", fakesys.FakeCmdResult{Error: errors.New("fake-error")})
			runner.AddCmdResult("umount /dev/xvdb2", fakesys.FakeCmdResult{})

			mounter := NewLinuxMounter(runner, fs, 1*time.Millisecond)

			didUnmount, err := mounter.Unmount("/dev/xvdb2")
			Expect(err).ToNot(HaveOccurred())
			Expect(didUnmount).To(BeTrue())

			Expect(3).To(Equal(len(runner.RunCommands)))
			Expect(runner.RunCommands[0]).To(Equal([]string{"umount", "/dev/xvdb2"}))
			Expect(runner.RunCommands[1]).To(Equal([]string{"umount", "/dev/xvdb2"}))
			Expect(runner.RunCommands[2]).To(Equal([]string{"umount", "/dev/xvdb2"}))
		})
		It("linux unmount when it fails too many times", func() {

			runner, fs := getLinuxMounterDependencies()
			fs.WriteFileString("/proc/mounts", "/dev/xvdb2 /var/vcap/data ext4")

			runner.AddCmdResult("umount /dev/xvdb2", fakesys.FakeCmdResult{Error: errors.New("fake-error"), Sticky: true})

			mounter := NewLinuxMounter(runner, fs, 1*time.Millisecond)

			_, err := mounter.Unmount("/dev/xvdb2")
			Expect(err).To(HaveOccurred())
		})
		It("is mount point", func() {

			runner, fs := getLinuxMounterDependencies()
			fs.WriteFileString("/proc/mounts", "/dev/xvdb2 /var/vcap/data ext4")

			mounter := NewLinuxMounter(runner, fs, 1*time.Millisecond)

			isMountPoint, err := mounter.IsMountPoint("/var/vcap/data")
			Expect(err).ToNot(HaveOccurred())
			Expect(isMountPoint).To(BeTrue())

			isMountPoint, err = mounter.IsMountPoint("/var/vcap/store")
			Expect(err).ToNot(HaveOccurred())
			Expect(isMountPoint).To(BeFalse())
		})
		It("is mounted", func() {

			runner, fs := getLinuxMounterDependencies()
			fs.WriteFileString("/proc/mounts", "/dev/xvdb2 /var/vcap/data ext4")

			mounter := NewLinuxMounter(runner, fs, 1*time.Millisecond)
			isMounted, err := mounter.IsMounted("/dev/xvdb2")
			Expect(err).ToNot(HaveOccurred())
			Expect(isMounted).To(BeTrue())

			isMounted, err = mounter.IsMounted("/var/vcap/data")
			Expect(err).ToNot(HaveOccurred())
			Expect(isMounted).To(BeTrue())

			isMounted, err = mounter.IsMounted("/var/foo")
			Expect(err).ToNot(HaveOccurred())
			Expect(isMounted).To(BeFalse())
		})
	})
}
