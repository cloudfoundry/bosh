package device_path_resolver

import (
	boshsys "bosh/system"
	"time"
)

type fakeDevicePathResolver struct {
	diskWaitTimeout time.Duration
	fs              boshsys.FileSystem
}

func NewFakeDevicePathResolver(diskWaitTimeout time.Duration, fs boshsys.FileSystem) (fakeDevicePathResolver fakeDevicePathResolver) {
	fakeDevicePathResolver.fs = fs
	fakeDevicePathResolver.diskWaitTimeout = diskWaitTimeout
	return
}

func (devicePathResolver fakeDevicePathResolver) GetRealDevicePath(devicePath string) (realPath string, err error) {
	return devicePath, nil
}
