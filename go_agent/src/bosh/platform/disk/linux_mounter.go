package disk

import (
	bosherr "bosh/errors"
	boshsys "bosh/system"
	"errors"
	"fmt"
	"strings"
)

type linuxMounter struct {
	runner boshsys.CmdRunner
	fs     boshsys.FileSystem
}

func newLinuxMounter(runner boshsys.CmdRunner, fs boshsys.FileSystem) (mounter linuxMounter) {
	mounter.runner = runner
	mounter.fs = fs
	return
}

func (m linuxMounter) Mount(partitionPath, mountPoint string) (err error) {
	shouldMount, err := m.shouldMount(partitionPath, mountPoint)
	if !shouldMount {
		return
	}

	if err != nil {
		err = bosherr.WrapError(err, "Checking whether partition should be mounted")
		return
	}

	_, _, err = m.runner.RunCommand("mount", partitionPath, mountPoint)
	if err != nil {
		err = bosherr.WrapError(err, "Shelling out to mount")
	}
	return
}

func (m linuxMounter) SwapOn(partitionPath string) (err error) {
	out, _, _ := m.runner.RunCommand("swapon", "-s")

	for i, swapOnLines := range strings.Split(out, "\n") {
		swapOnFields := strings.Fields(swapOnLines)

		switch {
		case i == 0:
			continue
		case len(swapOnFields) == 0:
			continue
		case swapOnFields[0] == partitionPath:
			return
		}
	}

	_, _, err = m.runner.RunCommand("swapon", partitionPath)
	if err != nil {
		err = bosherr.WrapError(err, "Shelling out to swapon")
	}
	return
}

func (m linuxMounter) shouldMount(partitionPath, mountPoint string) (shouldMount bool, err error) {
	mountInfo, err := m.fs.ReadFile("/proc/mounts")
	if err != nil {
		err = bosherr.WrapError(err, "Reading /proc/mounts")
		return
	}

	for _, mountEntry := range strings.Split(mountInfo, "\n") {
		if mountEntry == "" {
			continue
		}

		mountFields := strings.Fields(mountEntry)
		mountedDevicePath := mountFields[0]
		mountedMountPoint := mountFields[1]

		switch {
		case mountedDevicePath == partitionPath && mountedMountPoint == mountPoint:
			return
		case mountedDevicePath == partitionPath && mountedMountPoint != mountPoint:
			err = errors.New(fmt.Sprintf("Device %s is already mounted to %s, can't mount to %s",
				mountedDevicePath, mountedMountPoint, mountPoint))
			return
		case mountedMountPoint == mountPoint:
			err = errors.New(fmt.Sprintf("Device %s is already mounted to %s, can't mount %s",
				mountedDevicePath, mountedMountPoint, partitionPath))
			return
		}
	}

	shouldMount = true
	return
}
