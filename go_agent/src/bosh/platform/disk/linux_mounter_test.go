package disk_test

import (
	. "bosh/platform/disk"
	fakesys "bosh/system/fakes"
	"errors"
	"github.com/stretchr/testify/assert"

	. "github.com/onsi/ginkgo"
	"time"
)

type fsWithChangingFile struct {
	procMounts []string
	*fakesys.FakeFileSystem
}

func (fs *fsWithChangingFile) ReadFile(path string) (content string, err error) {
	if path == "/proc/mounts" {
		content = fs.procMounts[0]
		fs.procMounts = fs.procMounts[1:]
	}
	return
}

const SWAPON_USAGE_OUTPUT = `Filename				Type		Size	Used	Priority
/dev/swap                              partition	78180316	0	-1
`

const SWAPON_USAGE_OUTPUT_WITH_OTHER_DEVICE = `Filename				Type		Size	Used	Priority
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
			fs.WriteToFile("/proc/mounts", "")

			mounter := NewLinuxMounter(runner, fs, 1*time.Millisecond)
			err := mounter.Mount("/dev/foo", "/mnt/foo")

			assert.NoError(GinkgoT(), err)
			assert.Equal(GinkgoT(), 1, len(runner.RunCommands))
			assert.Equal(GinkgoT(), []string{"mount", "/dev/foo", "/mnt/foo"}, runner.RunCommands[0])
		})
		It("linux mount when disk is already mounted to the good mount point", func() {

			runner, fs := getLinuxMounterDependencies()
			fs.WriteToFile("/proc/mounts", "/dev/foo /mnt/foo\n/dev/bar /mnt/bar")

			mounter := NewLinuxMounter(runner, fs, 1*time.Millisecond)
			err := mounter.Mount("/dev/foo", "/mnt/foo")

			assert.NoError(GinkgoT(), err)
			assert.Equal(GinkgoT(), 0, len(runner.RunCommands))
		})
		It("linux mount when disk is already mounted to the wrong mount point", func() {

			runner, fs := getLinuxMounterDependencies()
			fs.WriteToFile("/proc/mounts", "/dev/foo /mnt/foobarbaz\n/dev/bar /mnt/bar")

			mounter := NewLinuxMounter(runner, fs, 1*time.Millisecond)
			err := mounter.Mount("/dev/foo", "/mnt/foo")

			assert.Error(GinkgoT(), err)
			assert.Equal(GinkgoT(), 0, len(runner.RunCommands))
		})
		It("linux mount when another disk is already mounted to mount point", func() {

			runner, fs := getLinuxMounterDependencies()
			fs.WriteToFile("/proc/mounts", "/dev/baz /mnt/foo\n/dev/bar /mnt/bar")

			mounter := NewLinuxMounter(runner, fs, 1*time.Millisecond)
			err := mounter.Mount("/dev/foo", "/mnt/foo")

			assert.Error(GinkgoT(), err)
			assert.Equal(GinkgoT(), 0, len(runner.RunCommands))
		})
		It("remount as readonly", func() {

			runner, fs := getLinuxMounterDependencies()

			procMounts := []string{"/dev/baz /mnt/bar ext4", "/dev/baz /mnt/bar ext4", ""}

			mounter := NewLinuxMounter(runner, &fsWithChangingFile{procMounts, fs}, 1*time.Millisecond)

			err := mounter.RemountAsReadonly("/mnt/bar")

			assert.NoError(GinkgoT(), err)
			assert.Equal(GinkgoT(), 2, len(runner.RunCommands))
			assert.Equal(GinkgoT(), []string{"umount", "/mnt/bar"}, runner.RunCommands[0])
			assert.Equal(GinkgoT(), []string{"mount", "/dev/baz", "/mnt/bar", "-o", "ro"}, runner.RunCommands[1])
		})
		It("remount", func() {

			runner, fs := getLinuxMounterDependencies()

			procMounts := []string{"/dev/baz /mnt/foo ext4", "/dev/baz /mnt/foo ext4", ""}

			mounter := NewLinuxMounter(runner, &fsWithChangingFile{procMounts, fs}, 1*time.Millisecond)

			err := mounter.Remount("/mnt/foo", "/mnt/bar")

			assert.NoError(GinkgoT(), err)
			assert.Equal(GinkgoT(), 2, len(runner.RunCommands))
			assert.Equal(GinkgoT(), []string{"umount", "/mnt/foo"}, runner.RunCommands[0])
			assert.Equal(GinkgoT(), []string{"mount", "/dev/baz", "/mnt/bar"}, runner.RunCommands[1])
		})
		It("linux swap on", func() {

			runner, fs := getLinuxMounterDependencies()
			runner.AddCmdResult("swapon -s", fakesys.FakeCmdResult{Stdout: "Filename				Type		Size	Used	Priority\n"})

			mounter := NewLinuxMounter(runner, fs, 1*time.Millisecond)
			mounter.SwapOn("/dev/swap")

			assert.Equal(GinkgoT(), 2, len(runner.RunCommands))
			assert.Equal(GinkgoT(), []string{"swapon", "/dev/swap"}, runner.RunCommands[1])
		})
		It("linux swap on when already on", func() {

			runner, fs := getLinuxMounterDependencies()
			runner.AddCmdResult("swapon -s", fakesys.FakeCmdResult{Stdout: SWAPON_USAGE_OUTPUT})

			mounter := NewLinuxMounter(runner, fs, 1*time.Millisecond)
			mounter.SwapOn("/dev/swap")
			assert.Equal(GinkgoT(), 1, len(runner.RunCommands))
			assert.Equal(GinkgoT(), []string{"swapon", "-s"}, runner.RunCommands[0])
		})
		It("linux swap on when already on other device", func() {

			runner, fs := getLinuxMounterDependencies()
			runner.AddCmdResult("swapon -s", fakesys.FakeCmdResult{Stdout: SWAPON_USAGE_OUTPUT_WITH_OTHER_DEVICE})

			mounter := NewLinuxMounter(runner, fs, 1*time.Millisecond)
			mounter.SwapOn("/dev/swap")
			assert.Equal(GinkgoT(), 2, len(runner.RunCommands))
			assert.Equal(GinkgoT(), []string{"swapon", "-s"}, runner.RunCommands[0])
			assert.Equal(GinkgoT(), []string{"swapon", "/dev/swap"}, runner.RunCommands[1])
		})
		It("linux unmount when partition is mounted", func() {

			runner, fs := getLinuxMounterDependencies()
			fs.WriteToFile("/proc/mounts", "/dev/xvdb2 /var/vcap/data ext4")

			mounter := NewLinuxMounter(runner, fs, 1*time.Millisecond)
			didUnmount, err := mounter.Unmount("/dev/xvdb2")
			assert.NoError(GinkgoT(), err)
			assert.True(GinkgoT(), didUnmount)

			assert.Equal(GinkgoT(), 1, len(runner.RunCommands))
			assert.Equal(GinkgoT(), []string{"umount", "/dev/xvdb2"}, runner.RunCommands[0])
		})
		It("linux unmount when mount point is mounted", func() {

			runner, fs := getLinuxMounterDependencies()
			fs.WriteToFile("/proc/mounts", "/dev/xvdb2 /var/vcap/data ext4")

			mounter := NewLinuxMounter(runner, fs, 1*time.Millisecond)
			didUnmount, err := mounter.Unmount("/var/vcap/data")
			assert.NoError(GinkgoT(), err)
			assert.True(GinkgoT(), didUnmount)

			assert.Equal(GinkgoT(), 1, len(runner.RunCommands))
			assert.Equal(GinkgoT(), []string{"umount", "/var/vcap/data"}, runner.RunCommands[0])
		})
		It("linux unmount when partition or mount point is not mounted", func() {

			runner, fs := getLinuxMounterDependencies()
			fs.WriteToFile("/proc/mounts", "/dev/xvdb2 /var/vcap/data ext4")

			mounter := NewLinuxMounter(runner, fs, 1*time.Millisecond)
			didUnmount, err := mounter.Unmount("/dev/xvdb3")
			assert.NoError(GinkgoT(), err)
			assert.False(GinkgoT(), didUnmount)

			assert.Equal(GinkgoT(), 0, len(runner.RunCommands))
		})
		It("linux unmount when it fails several times", func() {

			runner, fs := getLinuxMounterDependencies()
			fs.WriteToFile("/proc/mounts", "/dev/xvdb2 /var/vcap/data ext4")

			runner.AddCmdResult("umount /dev/xvdb2", fakesys.FakeCmdResult{Error: errors.New("fake-error")})
			runner.AddCmdResult("umount /dev/xvdb2", fakesys.FakeCmdResult{Error: errors.New("fake-error")})
			runner.AddCmdResult("umount /dev/xvdb2", fakesys.FakeCmdResult{})

			mounter := NewLinuxMounter(runner, fs, 1*time.Millisecond)

			didUnmount, err := mounter.Unmount("/dev/xvdb2")
			assert.NoError(GinkgoT(), err)
			assert.True(GinkgoT(), didUnmount)

			assert.Equal(GinkgoT(), 3, len(runner.RunCommands))
			assert.Equal(GinkgoT(), []string{"umount", "/dev/xvdb2"}, runner.RunCommands[0])
			assert.Equal(GinkgoT(), []string{"umount", "/dev/xvdb2"}, runner.RunCommands[1])
			assert.Equal(GinkgoT(), []string{"umount", "/dev/xvdb2"}, runner.RunCommands[2])
		})
		It("linux unmount when it fails too many times", func() {

			runner, fs := getLinuxMounterDependencies()
			fs.WriteToFile("/proc/mounts", "/dev/xvdb2 /var/vcap/data ext4")

			runner.AddCmdResult("umount /dev/xvdb2", fakesys.FakeCmdResult{Error: errors.New("fake-error"), Sticky: true})

			mounter := NewLinuxMounter(runner, fs, 1*time.Millisecond)

			_, err := mounter.Unmount("/dev/xvdb2")
			assert.Error(GinkgoT(), err)
		})
		It("is mount point", func() {

			runner, fs := getLinuxMounterDependencies()
			fs.WriteToFile("/proc/mounts", "/dev/xvdb2 /var/vcap/data ext4")

			mounter := NewLinuxMounter(runner, fs, 1*time.Millisecond)

			isMountPoint, err := mounter.IsMountPoint("/var/vcap/data")
			assert.NoError(GinkgoT(), err)
			assert.True(GinkgoT(), isMountPoint)

			isMountPoint, err = mounter.IsMountPoint("/var/vcap/store")
			assert.NoError(GinkgoT(), err)
			assert.False(GinkgoT(), isMountPoint)
		})
		It("is mounted", func() {

			runner, fs := getLinuxMounterDependencies()
			fs.WriteToFile("/proc/mounts", "/dev/xvdb2 /var/vcap/data ext4")

			mounter := NewLinuxMounter(runner, fs, 1*time.Millisecond)
			isMounted, err := mounter.IsMounted("/dev/xvdb2")
			assert.NoError(GinkgoT(), err)
			assert.True(GinkgoT(), isMounted)

			isMounted, err = mounter.IsMounted("/var/vcap/data")
			assert.NoError(GinkgoT(), err)
			assert.True(GinkgoT(), isMounted)

			isMounted, err = mounter.IsMounted("/var/foo")
			assert.NoError(GinkgoT(), err)
			assert.False(GinkgoT(), isMounted)
		})
	})
}
