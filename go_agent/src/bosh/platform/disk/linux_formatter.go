package disk

import (
	boshsys "bosh/system"
	"fmt"
	"strings"
)

type linuxFormatter struct {
	runner boshsys.CmdRunner
}

func NewLinuxFormatter(runner boshsys.CmdRunner) (formatter linuxFormatter) {
	formatter.runner = runner
	return
}

func (f linuxFormatter) Format(partitionPath string, fsType FileSystemType) (err error) {
	if f.partitionHasGivenType(partitionPath, fsType) {
		return
	}

	switch fsType {
	case FileSystemSwap:
		_, _, err = f.runner.RunCommand("mkswap", partitionPath)
	case FileSystemExt4:
		_, _, err = f.runner.RunCommand("mke2fs", "-t", "ext4", "-j", partitionPath)
	}
	return
}

func (f linuxFormatter) partitionHasGivenType(partitionPath string, fsType FileSystemType) bool {
	stdout, _, err := f.runner.RunCommand("blkid", "-p", partitionPath)
	if err != nil {
		return false
	}

	return strings.Contains(stdout, fmt.Sprintf(` TYPE="%s"`, fsType))
}
