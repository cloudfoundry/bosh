package fakes

import (
	boshsys "bosh/system"
)

type FakeFinder struct {
	FindPossibleDiskDeviceRealPath   string
	FindPossibleDiskDeviceFound      bool
	FindPossibleDiskDeviceDevicePath string
}

func (f *FakeFinder) FindPossibleDiskDevice(devicePath string, fs boshsys.FileSystem) (realPath string, found bool) {
	f.FindPossibleDiskDeviceDevicePath = devicePath
	realPath = f.FindPossibleDiskDeviceRealPath
	found = f.FindPossibleDiskDeviceFound
	return
}
