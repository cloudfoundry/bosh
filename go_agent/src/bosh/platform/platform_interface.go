package platform

import boshsettings "bosh/settings"

type Platform interface {
	SetupSsh(publicKey, username string) (err error)
	SetupDhcp(networks boshsettings.Networks) (err error)
	GetCpuLoad() (load CpuLoad, err error)
	GetCpuStats() (stats CpuStats, err error)
	GetMemStats() (stats MemStats, err error)
	GetSwapStats() (stats MemStats, err error)
	GetDiskStats(devicePath string) (stats DiskStats, err error)
}
