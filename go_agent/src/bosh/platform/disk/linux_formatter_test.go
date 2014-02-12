package disk_test

import (
	. "bosh/platform/disk"
	fakesys "bosh/system/fakes"
	. "github.com/onsi/ginkgo"
	"github.com/stretchr/testify/assert"
)

func init() {
	Describe("Testing with Ginkgo", func() {
		It("linux format when using swap fs", func() {

			fakeRunner := &fakesys.FakeCmdRunner{}
			fakeFs := &fakesys.FakeFileSystem{}
			fakeRunner.AddCmdResult("blkid -p /dev/xvda1", fakesys.FakeCmdResult{Stdout: `xxxxx TYPE="ext4" yyyy zzzz`})

			formatter := NewLinuxFormatter(fakeRunner, fakeFs)
			formatter.Format("/dev/xvda1", FileSystemSwap)

			assert.Equal(GinkgoT(), 2, len(fakeRunner.RunCommands))
			assert.Equal(GinkgoT(), []string{"mkswap", "/dev/xvda1"}, fakeRunner.RunCommands[1])
		})
		It("linux format when using swap fs and partition is swap", func() {

			fakeRunner := &fakesys.FakeCmdRunner{}
			fakeFs := &fakesys.FakeFileSystem{}
			fakeRunner.AddCmdResult("blkid -p /dev/xvda1", fakesys.FakeCmdResult{Stdout: `xxxxx TYPE="swap" yyyy zzzz`})

			formatter := NewLinuxFormatter(fakeRunner, fakeFs)
			formatter.Format("/dev/xvda1", FileSystemSwap)

			assert.Equal(GinkgoT(), 1, len(fakeRunner.RunCommands))
			assert.Equal(GinkgoT(), []string{"blkid", "-p", "/dev/xvda1"}, fakeRunner.RunCommands[0])
		})
		It("linux format when using ext4 fs with lazy itable support", func() {

			fakeRunner := &fakesys.FakeCmdRunner{}
			fakeFs := &fakesys.FakeFileSystem{}
			fakeFs.WriteToFile("/sys/fs/ext4/features/lazy_itable_init", "")
			fakeRunner.AddCmdResult("blkid -p /dev/xvda1", fakesys.FakeCmdResult{Stdout: `xxxxx TYPE="ext2" yyyy zzzz`})

			formatter := NewLinuxFormatter(fakeRunner, fakeFs)
			formatter.Format("/dev/xvda2", FileSystemExt4)

			assert.Equal(GinkgoT(), 2, len(fakeRunner.RunCommands))
			assert.Equal(GinkgoT(), []string{"mke2fs", "-t", "ext4", "-j", "-E", "lazy_itable_init=1", "/dev/xvda2"}, fakeRunner.RunCommands[1])
		})
		It("linux format when using ext4 fs without lazy itable support", func() {

			fakeRunner := &fakesys.FakeCmdRunner{}
			fakeFs := &fakesys.FakeFileSystem{}
			fakeRunner.AddCmdResult("blkid -p /dev/xvda1", fakesys.FakeCmdResult{Stdout: `xxxxx TYPE="ext2" yyyy zzzz`})

			formatter := NewLinuxFormatter(fakeRunner, fakeFs)
			formatter.Format("/dev/xvda2", FileSystemExt4)

			assert.Equal(GinkgoT(), 2, len(fakeRunner.RunCommands))
			assert.Equal(GinkgoT(), []string{"mke2fs", "-t", "ext4", "-j", "/dev/xvda2"}, fakeRunner.RunCommands[1])
		})
		It("linux format when using ext4 fs and partition is ext4", func() {

			fakeRunner := &fakesys.FakeCmdRunner{}
			fakeFs := &fakesys.FakeFileSystem{}
			fakeRunner.AddCmdResult("blkid -p /dev/xvda1", fakesys.FakeCmdResult{Stdout: `xxxxx TYPE="ext4" yyyy zzzz`})

			formatter := NewLinuxFormatter(fakeRunner, fakeFs)
			formatter.Format("/dev/xvda1", FileSystemExt4)

			assert.Equal(GinkgoT(), 1, len(fakeRunner.RunCommands))
			assert.Equal(GinkgoT(), []string{"blkid", "-p", "/dev/xvda1"}, fakeRunner.RunCommands[0])
		})
	})
}
