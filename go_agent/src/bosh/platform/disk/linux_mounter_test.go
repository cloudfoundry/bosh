package disk

import (
	testsys "bosh/system/testhelpers"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestLinuxMount(t *testing.T) {
	runner, fs := getLinuxMounterDependencies()
	fs.WriteToFile("/proc/mounts", "")

	mounter := NewLinuxMounter(runner, fs)
	err := mounter.Mount("/dev/foo", "/mnt/foo")

	assert.NoError(t, err)
	assert.Equal(t, 1, len(runner.RunCommands))
	assert.Equal(t, []string{"mount", "/dev/foo", "/mnt/foo"}, runner.RunCommands[0])
}

func TestLinuxMountWhenDiskIsAlreadyMountedToTheGoodMountPoint(t *testing.T) {
	runner, fs := getLinuxMounterDependencies()
	fs.WriteToFile("/proc/mounts", "/dev/foo /mnt/foo\n/dev/bar /mnt/bar")

	mounter := NewLinuxMounter(runner, fs)
	err := mounter.Mount("/dev/foo", "/mnt/foo")

	assert.NoError(t, err)
	assert.Equal(t, 0, len(runner.RunCommands))
}

func TestLinuxMountWhenDiskIsAlreadyMountedToTheWrongMountPoint(t *testing.T) {
	runner, fs := getLinuxMounterDependencies()
	fs.WriteToFile("/proc/mounts", "/dev/foo /mnt/foobarbaz\n/dev/bar /mnt/bar")

	mounter := NewLinuxMounter(runner, fs)
	err := mounter.Mount("/dev/foo", "/mnt/foo")

	assert.Error(t, err)
	assert.Equal(t, 0, len(runner.RunCommands))
}

func TestLinuxMountWhenAnotherDiskIsAlreadyMountedToMountPoint(t *testing.T) {
	runner, fs := getLinuxMounterDependencies()
	fs.WriteToFile("/proc/mounts", "/dev/baz /mnt/foo\n/dev/bar /mnt/bar")

	mounter := NewLinuxMounter(runner, fs)
	err := mounter.Mount("/dev/foo", "/mnt/foo")

	assert.Error(t, err)
	assert.Equal(t, 0, len(runner.RunCommands))
}

func TestLinuxSwapOn(t *testing.T) {
	runner, fs := getLinuxMounterDependencies()

	mounter := NewLinuxMounter(runner, fs)
	mounter.SwapOn("/dev/swap")

	assert.Equal(t, 1, len(runner.RunCommands))
	assert.Equal(t, []string{"swapon", "/dev/swap"}, runner.RunCommands[0])
}

func getLinuxMounterDependencies() (runner *testsys.FakeCmdRunner, fs *testsys.FakeFileSystem) {
	runner = &testsys.FakeCmdRunner{}
	fs = &testsys.FakeFileSystem{}
	return
}
