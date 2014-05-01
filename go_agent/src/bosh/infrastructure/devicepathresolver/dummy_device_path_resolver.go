package devicepathresolver

import (
	"time"

	boshsys "bosh/system"
)

type dummyDevicePathResolver struct {
	diskWaitTimeout time.Duration
	fs              boshsys.FileSystem
}

func NewDummyDevicePathResolver(diskWaitTimeout time.Duration, fs boshsys.FileSystem) dummyDevicePathResolver {
	return dummyDevicePathResolver{diskWaitTimeout, fs}
}

func (resolver dummyDevicePathResolver) GetRealDevicePath(devicePath string) (string, error) {
	return devicePath, nil
}
