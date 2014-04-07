package fakes

import (
	boshdpresolv "bosh/infrastructure/devicepathresolver"
	boshsettings "bosh/settings"
)

type FakeInfrastructure struct {
	Settings                boshsettings.Settings
	SetupSshUsername        string
	SetupNetworkingNetworks boshsettings.Networks

	GetEphemeralDiskPathDevicePath string
	GetEphemeralDiskPathFound      bool
	GetEphemeralDiskPathRealPath   string

	MountPersistentDiskVolumeID   string
	MountPersistentDiskMountPoint string
	MountPersistentDiskError      error
	DevicePathResolver            boshdpresolv.DevicePathResolver
}

func NewFakeInfrastructure() (infrastructure *FakeInfrastructure) {
	infrastructure = &FakeInfrastructure{}
	infrastructure.Settings = boshsettings.Settings{}
	return
}

func (i *FakeInfrastructure) GetDevicePathResolver() (devicePathResolver boshdpresolv.DevicePathResolver) {
	return i.DevicePathResolver
}

func (i *FakeInfrastructure) SetupSsh(username string) (err error) {
	i.SetupSshUsername = username
	return
}

func (i *FakeInfrastructure) GetSettings() (settings boshsettings.Settings, err error) {
	settings = i.Settings
	return
}

func (i *FakeInfrastructure) SetupNetworking(networks boshsettings.Networks) (err error) {
	i.SetupNetworkingNetworks = networks
	return
}

func (i *FakeInfrastructure) GetEphemeralDiskPath(devicePath string) (realPath string, found bool) {
	i.GetEphemeralDiskPathDevicePath = devicePath
	realPath = i.GetEphemeralDiskPathRealPath
	found = i.GetEphemeralDiskPathFound
	return
}

func (i *FakeInfrastructure) MountPersistentDisk(volumeID string, mountPoint string) (err error) {
	i.MountPersistentDiskVolumeID = volumeID
	i.MountPersistentDiskMountPoint = mountPoint
	err = i.MountPersistentDiskError
	return
}
