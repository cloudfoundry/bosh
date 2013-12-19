package disk

import (
	fakesys "bosh/system/fakes"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestLinuxFormatWhenUsingSwapFs(t *testing.T) {
	fakeRunner := &fakesys.FakeCmdRunner{}
	fakeFs := &fakesys.FakeFileSystem{}
	fakeRunner.AddCmdResult("blkid -p /dev/xvda1", fakesys.FakeCmdResult{Stdout: `xxxxx TYPE="ext4" yyyy zzzz`})

	formatter := newLinuxFormatter(fakeRunner, fakeFs)
	formatter.Format("/dev/xvda1", FileSystemSwap)

	assert.Equal(t, 2, len(fakeRunner.RunCommands))
	assert.Equal(t, []string{"mkswap", "/dev/xvda1"}, fakeRunner.RunCommands[1])
}

func TestLinuxFormatWhenUsingSwapFsAndPartitionIsSwap(t *testing.T) {
	fakeRunner := &fakesys.FakeCmdRunner{}
	fakeFs := &fakesys.FakeFileSystem{}
	fakeRunner.AddCmdResult("blkid -p /dev/xvda1", fakesys.FakeCmdResult{Stdout: `xxxxx TYPE="swap" yyyy zzzz`})

	formatter := newLinuxFormatter(fakeRunner, fakeFs)
	formatter.Format("/dev/xvda1", FileSystemSwap)

	assert.Equal(t, 1, len(fakeRunner.RunCommands))
	assert.Equal(t, []string{"blkid", "-p", "/dev/xvda1"}, fakeRunner.RunCommands[0])
}

func TestLinuxFormatWhenUsingExt4FsWithLazyItableSupport(t *testing.T) {
	fakeRunner := &fakesys.FakeCmdRunner{}
	fakeFs := &fakesys.FakeFileSystem{}
	fakeFs.WriteToFile("/sys/fs/ext4/features/lazy_itable_init", "")
	fakeRunner.AddCmdResult("blkid -p /dev/xvda1", fakesys.FakeCmdResult{Stdout: `xxxxx TYPE="ext2" yyyy zzzz`})

	formatter := newLinuxFormatter(fakeRunner, fakeFs)
	formatter.Format("/dev/xvda2", FileSystemExt4)

	assert.Equal(t, 2, len(fakeRunner.RunCommands))
	assert.Equal(t, []string{"mke2fs", "-t", "ext4", "-j", "-E", "lazy_itable_init=1", "/dev/xvda2"}, fakeRunner.RunCommands[1])
}

func TestLinuxFormatWhenUsingExt4FsWithoutLazyItableSupport(t *testing.T) {
	fakeRunner := &fakesys.FakeCmdRunner{}
	fakeFs := &fakesys.FakeFileSystem{}
	fakeRunner.AddCmdResult("blkid -p /dev/xvda1", fakesys.FakeCmdResult{Stdout: `xxxxx TYPE="ext2" yyyy zzzz`})

	formatter := newLinuxFormatter(fakeRunner, fakeFs)
	formatter.Format("/dev/xvda2", FileSystemExt4)

	assert.Equal(t, 2, len(fakeRunner.RunCommands))
	assert.Equal(t, []string{"mke2fs", "-t", "ext4", "-j", "/dev/xvda2"}, fakeRunner.RunCommands[1])
}

func TestLinuxFormatWhenUsingExt4FsAndPartitionIsExt4(t *testing.T) {
	fakeRunner := &fakesys.FakeCmdRunner{}
	fakeFs := &fakesys.FakeFileSystem{}
	fakeRunner.AddCmdResult("blkid -p /dev/xvda1", fakesys.FakeCmdResult{Stdout: `xxxxx TYPE="ext4" yyyy zzzz`})

	formatter := newLinuxFormatter(fakeRunner, fakeFs)
	formatter.Format("/dev/xvda1", FileSystemExt4)

	assert.Equal(t, 1, len(fakeRunner.RunCommands))
	assert.Equal(t, []string{"blkid", "-p", "/dev/xvda1"}, fakeRunner.RunCommands[0])
}
