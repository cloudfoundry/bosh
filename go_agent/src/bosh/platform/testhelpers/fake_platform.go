package testhelpers

import (
	"bosh/platform"
	"bosh/settings"
)

type FakePlatform struct {
	CpuLoad   platform.CpuLoad
	CpuStats  platform.CpuStats
	MemStats  platform.MemStats
	SwapStats platform.MemStats
	DiskStats map[string]platform.DiskStats
}

func (p *FakePlatform) SetupSsh(publicKey, username string) (err error) {
	return
}

func (p *FakePlatform) SetupDhcp(networks settings.Networks) (err error) {
	return
}

func (p *FakePlatform) GetCpuLoad() (load platform.CpuLoad, err error) {
	load = p.CpuLoad
	return
}

func (p *FakePlatform) GetCpuStats() (stats platform.CpuStats, err error) {
	stats = p.CpuStats
	return
}

func (p *FakePlatform) GetMemStats() (stats platform.MemStats, err error) {
	stats = p.MemStats
	return
}

func (p *FakePlatform) GetSwapStats() (stats platform.MemStats, err error) {
	stats = p.SwapStats
	return
}

func (p *FakePlatform) GetDiskStats(devicePath string) (stats platform.DiskStats, err error) {
	stats = p.DiskStats[devicePath]
	return
}
