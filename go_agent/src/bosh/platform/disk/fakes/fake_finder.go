package fakes

import (
	"bosh/infrastructure"
	boshsys "bosh/system"
)

type FakeFinder struct {
	GetEphemeralDiskPathRealPath    string
	GetEphemeralDiskPathFound       bool
	GetEphemeralDiskPathDevicePath  string
	GetPersistentDiskPathRealPath   string
	GetPersistentDiskPathFound      bool
	GetPersistentDiskPathDevicePath string
}

func (f *FakeFinder) GetEphemeralDiskPath(devicePath string, fs boshsys.FileSystem) (realPath string, found bool) {
	f.GetEphemeralDiskPathDevicePath = devicePath
	realPath = f.GetEphemeralDiskPathRealPath
	found = f.GetEphemeralDiskPathFound
	return
}

func (f *FakeFinder) GetPersistentDiskPath(devicePath string, fs boshsys.FileSystem, scsiDelegate infrastructure.ScsiDelegate) (realPath string, found bool) {
	f.GetPersistentDiskPathDevicePath = devicePath
	realPath = f.GetPersistentDiskPathRealPath
	found = f.GetPersistentDiskPathFound
	return
}
