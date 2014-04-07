package devicepathresolver

import (
	boshsys "bosh/system"
	"time"
)

type dummyDevicePathResolver struct {
	diskWaitTimeout time.Duration
	fs              boshsys.FileSystem
}

func NewDummyDevicePathResolver(diskWaitTimeout time.Duration, fs boshsys.FileSystem) (dummyDevicePathResolver dummyDevicePathResolver) {
	dummyDevicePathResolver.fs = fs
	dummyDevicePathResolver.diskWaitTimeout = diskWaitTimeout
	return
}

func (devicePathResolver dummyDevicePathResolver) GetRealDevicePath(devicePath string) (realPath string, err error) {
	return devicePath, nil
}
