package platform

import (
	boshstats "bosh/platform/stats"
	boshsettings "bosh/settings"
)

type Platform interface {
	SetupRuntimeConfiguration() (err error)
	SetupSsh(publicKey, username string) (err error)
	SetupDhcp(networks boshsettings.Networks) (err error)
	SetupEphemeralDiskWithPath(devicePath, mountPoint string) (err error)
	GetStatsCollector() (statsCollector boshstats.StatsCollector)
}
