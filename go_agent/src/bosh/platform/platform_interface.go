package platform

import (
	boshstats "bosh/platform/stats"
	boshsettings "bosh/settings"
)

type Platform interface {
	GetStatsCollector() (statsCollector boshstats.StatsCollector)
	SetupRuntimeConfiguration() (err error)
	SetupSsh(publicKey, username string) (err error)
	SetUserPassword(user, encryptedPwd string) (err error)
	SetupHostname(hostname string) (err error)
	SetupDhcp(networks boshsettings.Networks) (err error)
	SetTimeWithNtpServers(servers []string, serversFilePath string) (err error)
	SetupEphemeralDiskWithPath(devicePath, mountPoint string) (err error)
}
