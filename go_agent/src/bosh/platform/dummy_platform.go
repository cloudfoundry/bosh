package platform

import "bosh/settings"

type dummyPlatform struct {
}

func newDummyPlatform() (p dummyPlatform) {
	return
}

func (p dummyPlatform) SetupSsh(publicKey, username string) (err error) {
	return
}

func (p dummyPlatform) SetupDhcp(networks settings.Networks) (err error) {
	return
}

func (p dummyPlatform) GetCpuLoad() (load CpuLoad, err error) {
	return
}

func (p dummyPlatform) GetCpuStats() (stats CpuStats, err error) {
	return
}

func (p dummyPlatform) GetMemStats() (stats MemStats, err error) {
	return
}

func (p dummyPlatform) GetSwapStats() (stats MemStats, err error) {
	return
}

func (p dummyPlatform) GetDiskStats(devicePath string) (stats DiskStats, err error) {
	return
}
