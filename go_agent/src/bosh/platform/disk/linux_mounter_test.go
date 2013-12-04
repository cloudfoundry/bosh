package disk

import (
	fakesys "bosh/system/fakes"
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

func TestLinuxSwapOn(t *testing.T) {
	runner, fs := getLinuxMounterDependencies()
	runner.AddCmdResult("swapon -s", []string{"Filename				Type		Size	Used	Priority\n", ""})

	mounter := newLinuxMounter(runner, fs)
	mounter.SwapOn("/dev/swap")

	assert.Equal(t, 2, len(runner.RunCommands))
	assert.Equal(t, []string{"swapon", "/dev/swap"}, runner.RunCommands[1])
}

func TestLinuxSwapOnWhenAlreadyOn(t *testing.T) {
	runner, fs := getLinuxMounterDependencies()
	runner.AddCmdResult("swapon -s", []string{SWAPON_USAGE_OUTPUT, ""})

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
	runner.AddCmdResult("swapon -s", []string{SWAPON_USAGE_OUTPUT_WITH_OTHER_DEVICE, ""})

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

func TestLinuxUnmountWhenPartitionIsNotMounted(t *testing.T) {
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

	runner.AddCmdResult("umount /dev/xvdb2", []string{"", "error"})
	runner.AddCmdResult("umount /dev/xvdb2", []string{"", "error"})
	runner.AddCmdResult("umount /dev/xvdb2", []string{"", ""})

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

	runner.AddCmdResult("umount /dev/xvdb2", []string{"", "error"})
	runner.AddCmdResult("umount /dev/xvdb2", []string{"", "error"})

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

func getLinuxMounterDependencies() (runner *fakesys.FakeCmdRunner, fs *fakesys.FakeFileSystem) {
	runner = &fakesys.FakeCmdRunner{}
	fs = &fakesys.FakeFileSystem{}
	return
}
