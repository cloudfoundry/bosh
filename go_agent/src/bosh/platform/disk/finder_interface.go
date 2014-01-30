package disk

import (
	"bosh/infrastructure"
	boshsys "bosh/system"
)

type Finder interface {
	GetEphemeralDiskPath(devicePathOrCid string, fs boshsys.FileSystem) (realPath string, found bool)
	GetPersistentDiskPath(devicePathOrCid string, fs boshsys.FileSystem, scsiDelegate infrastructure.ScsiDelegate) (realPath string, found bool)
}
