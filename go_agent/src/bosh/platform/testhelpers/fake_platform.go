package testhelpers

import (
	boshplatform "bosh/platform"
	boshsettings "bosh/settings"
)

type FakePlatform struct {
	SetupEphemeralDiskWithPathDevicePath string
	SetupEphemeralDiskWithPathMountPoint string

	CpuLoad   boshplatform.CpuLoad
	CpuStats  boshplatform.CpuStats
	MemStats  boshplatform.MemStats
	SwapStats boshplatform.MemStats
	DiskStats map[string]boshplatform.DiskStats
}

func (p *FakePlatform) SetupSsh(publicKey, username string) (err error) {
	return
}

func (p *FakePlatform) SetupDhcp(networks boshsettings.Networks) (err error) {
	return
}

func (p *FakePlatform) SetupEphemeralDiskWithPath(devicePath, mountPoint string) (err error) {
	p.SetupEphemeralDiskWithPathDevicePath = devicePath
	p.SetupEphemeralDiskWithPathMountPoint = mountPoint
	return
}

func (p *FakePlatform) GetCpuLoad() (load boshplatform.CpuLoad, err error) {
	load = p.CpuLoad
	return
}

func (p *FakePlatform) GetCpuStats() (stats boshplatform.CpuStats, err error) {
	stats = p.CpuStats
	return
}

func (p *FakePlatform) GetMemStats() (stats boshplatform.MemStats, err error) {
	stats = p.MemStats
	return
}

func (p *FakePlatform) GetSwapStats() (stats boshplatform.MemStats, err error) {
	stats = p.SwapStats
	return
}

func (p *FakePlatform) GetDiskStats(devicePath string) (stats boshplatform.DiskStats, err error) {
	stats = p.DiskStats[devicePath]
	return
}
