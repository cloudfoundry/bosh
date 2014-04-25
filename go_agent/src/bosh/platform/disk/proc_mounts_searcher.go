package disk

import (
	"strings"

	bosherr "bosh/errors"
	boshsys "bosh/system"
)

type procMountsSearcher struct {
	fs boshsys.FileSystem
}

func NewProcMountsSearcher(fs boshsys.FileSystem) procMountsSearcher {
	return procMountsSearcher{fs}
}

func (s procMountsSearcher) SearchMounts(mountFieldsFunc MountSearchCallBack) (bool, error) {
	mountInfo, err := s.fs.ReadFileString("/proc/mounts")
	if err != nil {
		return false, bosherr.WrapError(err, "Reading /proc/mounts")
	}

	for _, mountEntry := range strings.Split(mountInfo, "\n") {
		if mountEntry == "" {
			continue
		}
		mountFields := strings.Fields(mountEntry)
		mountedPartitionPath := mountFields[0]
		mountedMountPoint := mountFields[1]

		found, err := mountFieldsFunc(mountedPartitionPath, mountedMountPoint)
		if found || err != nil {
			return found, err
		}
	}

	return false, nil
}
