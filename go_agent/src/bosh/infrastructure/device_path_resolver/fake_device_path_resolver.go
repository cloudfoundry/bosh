package device_path_resolver

import (
	boshsys "bosh/system"
	"time"
)

type FakeDevicePathResolver struct {
	diskWaitTimeout time.Duration
	fs              boshsys.FileSystem
	RealDevicePath  string
}

func NewFakeDevicePathResolver(diskWaitTimeout time.Duration, fs boshsys.FileSystem) (fakeDevicePathResolver *FakeDevicePathResolver) {
	fakeDevicePathResolver = &FakeDevicePathResolver{}
	fakeDevicePathResolver.fs = fs
	fakeDevicePathResolver.diskWaitTimeout = diskWaitTimeout
	return
}

func (devicePathResolver *FakeDevicePathResolver) GetRealDevicePath(devicePath string) (realPath string, err error) {
	realPath = devicePathResolver.RealDevicePath
	return
}
