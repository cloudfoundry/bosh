package disk

import (
	boshsys "bosh/system"
)

type Finder interface {
	FindPossibleDiskDevice(devicePathOrCid string, fs boshsys.FileSystem) (realPath string, found bool)
}
