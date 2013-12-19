package disk

import (
	fakesys "bosh/system/fakes"
	"errors"
	"github.com/stretchr/testify/assert"
	"testing"
	"time"
)

func TestLinuxMount(t *testing.T) {
	runner, fs := getLinuxMounterDependencies()
	fs.WriteToFile("/proc/mounts", "")

	mounter := newLinuxMounter(runner, fs)
	err := mounter.Mount("/dev/foo", "/mnt/foo")

	assert.NoError(t, err)
	assert.Equal(t, 1, len(runner.RunCommands))
	assert.Equal(t, []string{"mount", "/dev/foo", "/mnt/foo"}, runner.RunCommands[0])
}

func TestLinuxMountWhenDiskIsAlreadyMountedToTheGoodMountPoint(t *testing.T) {
	runner, fs := getLinuxMounterDependencies()
	fs.WriteToFile("/proc/mounts", "/dev/foo /mnt/foo\n/dev/bar /mnt/bar")

	mounter := newLinuxMounter(runner, fs)
	err := mounter.Mount("/dev/foo", "/mnt/foo")

	assert.NoError(t, err)
	assert.Equal(t, 0, len(runner.RunCommands))
}

func TestLinuxMountWhenDiskIsAlreadyMountedToTheWrongMountPoint(t *testing.T) {
	runner, fs := getLinuxMounterDependencies()
	fs.WriteToFile("/proc/mounts", "/dev/foo /mnt/foobarbaz\n/dev/bar /mnt/bar")

	mounter := newLinuxMounter(runner, fs)
	err := mounter.Mount("/dev/foo", "/mnt/foo")

	assert.Error(t, err)
	assert.Equal(t, 0, len(runner.RunCommands))
}

func TestLinuxMountWhenAnotherDiskIsAlreadyMountedToMountPoint(t *testing.T) {
	runner, fs := getLinuxMounterDependencies()
	fs.WriteToFile("/proc/mounts", "/dev/baz /mnt/foo\n/dev/bar /mnt/bar")

	mounter := newLinuxMounter(runner, fs)
	err := mounter.Mount("/dev/foo", "/mnt/foo")

	assert.Error(t, err)
	assert.Equal(t, 0, len(runner.RunCommands))
}

// For testing remount and remount as readonly we need to change the /proc/mounts file
// as the partition gets unmounted then remounted
//
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

func TestRemountAsReadonly(t *testing.T) {
	runner, fs := getLinuxMounterDependencies()

	procMounts := []string{"/dev/baz /mnt/bar ext4", "/dev/baz /mnt/bar ext4", ""}

	mounter := newLinuxMounter(runner, &fsWithChangingFile{procMounts, fs})

	err := mounter.RemountAsReadonly("/mnt/bar")

	assert.NoError(t, err)
	assert.Equal(t, 2, len(runner.RunCommands))
	assert.Equal(t, []string{"umount", "/mnt/bar"}, runner.RunCommands[0])
	assert.Equal(t, []string{"mount", "/dev/baz", "/mnt/bar", "-o", "ro"}, runner.RunCommands[1])
}

func TestRemount(t *testing.T) {
	runner, fs := getLinuxMounterDependencies()

	procMounts := []string{"/dev/baz /mnt/foo ext4", "/dev/baz /mnt/foo ext4", ""}

	mounter := newLinuxMounter(runner, &fsWithChangingFile{procMounts, fs})

	err := mounter.Remount("/mnt/foo", "/mnt/bar")

	assert.NoError(t, err)
	assert.Equal(t, 2, len(runner.RunCommands))
	assert.Equal(t, []string{"umount", "/mnt/foo"}, runner.RunCommands[0])
	assert.Equal(t, []string{"mount", "/dev/baz", "/mnt/bar"}, runner.RunCommands[1])
}

func TestLinuxSwapOn(t *testing.T) {
	runner, fs := getLinuxMounterDependencies()
	runner.AddCmdResult("swapon -s", fakesys.FakeCmdResult{Stdout: "Filename				Type		Size	Used	Priority\n"})

	mounter := newLinuxMounter(runner, fs)
	mounter.SwapOn("/dev/swap")

	assert.Equal(t, 2, len(runner.RunCommands))
	assert.Equal(t, []string{"swapon", "/dev/swap"}, runner.RunCommands[1])
}

func TestLinuxSwapOnWhenAlreadyOn(t *testing.T) {
	runner, fs := getLinuxMounterDependencies()
	runner.AddCmdResult("swapon -s", fakesys.FakeCmdResult{Stdout: SWAPON_USAGE_OUTPUT})

	mounter := newLinuxMounter(runner, fs)
	mounter.SwapOn("/dev/swap")
	assert.Equal(t, 1, len(runner.RunCommands))
	assert.Equal(t, []string{"swapon", "-s"}, runner.RunCommands[0])
}

const SWAPON_USAGE_OUTPUT = `Filename				Type		Size	Used	Priority
/dev/swap                              partition	78180316	0	-1
`

func TestLinuxSwapOnWhenAlreadyOnOtherDevice(t *testing.T) {
	runner, fs := getLinuxMounterDependencies()
	runner.AddCmdResult("swapon -s", fakesys.FakeCmdResult{Stdout: SWAPON_USAGE_OUTPUT_WITH_OTHER_DEVICE})

	mounter := newLinuxMounter(runner, fs)
	mounter.SwapOn("/dev/swap")
	assert.Equal(t, 2, len(runner.RunCommands))
	assert.Equal(t, []string{"swapon", "-s"}, runner.RunCommands[0])
	assert.Equal(t, []string{"swapon", "/dev/swap"}, runner.RunCommands[1])
}

const SWAPON_USAGE_OUTPUT_WITH_OTHER_DEVICE = `Filename				Type		Size	Used	Priority
/dev/swap2                              partition	78180316	0	-1
`

func TestLinuxUnmountWhenPartitionIsMounted(t *testing.T) {
	runner, fs := getLinuxMounterDependencies()
	fs.WriteToFile("/proc/mounts", "/dev/xvdb2 /var/vcap/data ext4")

	mounter := newLinuxMounter(runner, fs)
	didUnmount, err := mounter.Unmount("/dev/xvdb2")
	assert.NoError(t, err)
	assert.True(t, didUnmount)

	assert.Equal(t, 1, len(runner.RunCommands))
	assert.Equal(t, []string{"umount", "/dev/xvdb2"}, runner.RunCommands[0])
}

func TestLinuxUnmountWhenMountPointIsMounted(t *testing.T) {
	runner, fs := getLinuxMounterDependencies()
	fs.WriteToFile("/proc/mounts", "/dev/xvdb2 /var/vcap/data ext4")

	mounter := newLinuxMounter(runner, fs)
	didUnmount, err := mounter.Unmount("/var/vcap/data")
	assert.NoError(t, err)
	assert.True(t, didUnmount)

	assert.Equal(t, 1, len(runner.RunCommands))
	assert.Equal(t, []string{"umount", "/var/vcap/data"}, runner.RunCommands[0])
}

func TestLinuxUnmountWhenPartitionOrMountPointIsNotMounted(t *testing.T) {
	runner, fs := getLinuxMounterDependencies()
	fs.WriteToFile("/proc/mounts", "/dev/xvdb2 /var/vcap/data ext4")

	mounter := newLinuxMounter(runner, fs)
	didUnmount, err := mounter.Unmount("/dev/xvdb3")
	assert.NoError(t, err)
	assert.False(t, didUnmount)

	assert.Equal(t, 0, len(runner.RunCommands))
}

func TestLinuxUnmountWhenItFailsSeveralTimes(t *testing.T) {
	runner, fs := getLinuxMounterDependencies()
	fs.WriteToFile("/proc/mounts", "/dev/xvdb2 /var/vcap/data ext4")

	runner.AddCmdResult("umount /dev/xvdb2", fakesys.FakeCmdResult{Error: errors.New("fake-error")})
	runner.AddCmdResult("umount /dev/xvdb2", fakesys.FakeCmdResult{Error: errors.New("fake-error")})
	runner.AddCmdResult("umount /dev/xvdb2", fakesys.FakeCmdResult{})

	mounter := newLinuxMounter(runner, fs)
	mounter.unmountRetrySleep = 1 * time.Millisecond

	didUnmount, err := mounter.Unmount("/dev/xvdb2")
	assert.NoError(t, err)
	assert.True(t, didUnmount)

	assert.Equal(t, 3, len(runner.RunCommands))
	assert.Equal(t, []string{"umount", "/dev/xvdb2"}, runner.RunCommands[0])
	assert.Equal(t, []string{"umount", "/dev/xvdb2"}, runner.RunCommands[1])
	assert.Equal(t, []string{"umount", "/dev/xvdb2"}, runner.RunCommands[2])
}

func TestLinuxUnmountWhenItFailsTooManyTimes(t *testing.T) {
	runner, fs := getLinuxMounterDependencies()
	fs.WriteToFile("/proc/mounts", "/dev/xvdb2 /var/vcap/data ext4")

	runner.AddCmdResult("umount /dev/xvdb2", fakesys.FakeCmdResult{Error: errors.New("fake-error")})
	runner.AddCmdResult("umount /dev/xvdb2", fakesys.FakeCmdResult{Error: errors.New("fake-error")})

	mounter := newLinuxMounter(runner, fs)
	mounter.maxUnmountRetries = 2
	mounter.unmountRetrySleep = 1 * time.Millisecond

	_, err := mounter.Unmount("/dev/xvdb2")
	assert.Error(t, err)
	assert.Equal(t, 2, len(runner.RunCommands))
}

func TestIsMountPoint(t *testing.T) {
	runner, fs := getLinuxMounterDependencies()
	fs.WriteToFile("/proc/mounts", "/dev/xvdb2 /var/vcap/data ext4")

	mounter := newLinuxMounter(runner, fs)

	isMountPoint, err := mounter.IsMountPoint("/var/vcap/data")
	assert.NoError(t, err)
	assert.True(t, isMountPoint)

	isMountPoint, err = mounter.IsMountPoint("/var/vcap/store")
	assert.NoError(t, err)
	assert.False(t, isMountPoint)
}

func TestIsMounted(t *testing.T) {
	runner, fs := getLinuxMounterDependencies()
	fs.WriteToFile("/proc/mounts", "/dev/xvdb2 /var/vcap/data ext4")

	mounter := newLinuxMounter(runner, fs)
	isMounted, err := mounter.IsMounted("/dev/xvdb2")
	assert.NoError(t, err)
	assert.True(t, isMounted)

	isMounted, err = mounter.IsMounted("/var/vcap/data")
	assert.NoError(t, err)
	assert.True(t, isMounted)

	isMounted, err = mounter.IsMounted("/var/foo")
	assert.NoError(t, err)
	assert.False(t, isMounted)
}

func getLinuxMounterDependencies() (runner *fakesys.FakeCmdRunner, fs *fakesys.FakeFileSystem) {
	runner = &fakesys.FakeCmdRunner{}
	fs = &fakesys.FakeFileSystem{}
	return
}
