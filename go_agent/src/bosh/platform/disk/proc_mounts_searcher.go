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

func (s procMountsSearcher) SearchMounts() ([]Mount, error) {
	var mounts []Mount

	mountInfo, err := s.fs.ReadFileString("/proc/mounts")
	if err != nil {
		return mounts, bosherr.WrapError(err, "Reading /proc/mounts")
	}

	for _, mountEntry := range strings.Split(mountInfo, "\n") {
		if mountEntry == "" {
			continue
		}

		mountFields := strings.Fields(mountEntry)

		mounts = append(mounts, Mount{
			PartitionPath: mountFields[0],
			MountPoint:    mountFields[1],
		})
	}

	return mounts, nil
}
