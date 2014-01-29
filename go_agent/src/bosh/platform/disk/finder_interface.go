package disk

import (
	boshsys "bosh/system"
)

type Finder interface {
	FindPossibleDiskDevice(devicePath string, fs boshsys.FileSystem) (realPath string, found bool)
}
