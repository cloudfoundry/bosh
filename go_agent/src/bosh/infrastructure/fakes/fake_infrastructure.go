package fakes

import (
	boshsettings "bosh/settings"
)

type FakeInfrastructure struct {
	Settings                boshsettings.Settings
	SetupSshUsername        string
	SetupNetworkingNetworks boshsettings.Networks

	GetEphemeralDiskPathDevicePath string
	GetEphemeralDiskPathFound      bool
	GetEphemeralDiskPathRealPath   string

	MountPersistentDiskVolumeId   string
	MountPersistentDiskMountPoint string
	MountPersistentDiskError      error
}

func NewFakeInfrastructure() (infrastructure *FakeInfrastructure) {
	infrastructure = &FakeInfrastructure{}
	infrastructure.Settings = boshsettings.Settings{}
	return
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

func (i *FakeInfrastructure) MountPersistentDisk(volumeId string, mountPoint string) (err error) {
	i.MountPersistentDiskVolumeId = volumeId
	i.MountPersistentDiskMountPoint = mountPoint
	err = i.MountPersistentDiskError
	return
}
