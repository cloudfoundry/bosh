package platform

import (
	boshcmd "bosh/platform/commands"
	boshstats "bosh/platform/stats"
	boshsettings "bosh/settings"
	boshsys "bosh/system"
)

type Platform interface {
	GetFs() (fs boshsys.FileSystem)
	GetRunner() (runner boshsys.CmdRunner)
	GetStatsCollector() (statsCollector boshstats.StatsCollector)
	GetCompressor() (compressor boshcmd.Compressor)

	SetupRuntimeConfiguration() (err error)
	CreateUser(username, password, basePath string) (err error)
	AddUserToGroups(username string, groups []string) (err error)
	DeleteEphemeralUsersMatching(regex string) (err error)
	SetupSsh(publicKey, username string) (err error)
	SetUserPassword(user, encryptedPwd string) (err error)
	SetupHostname(hostname string) (err error)
	SetupDhcp(networks boshsettings.Networks) (err error)
	SetupLogrotate(groupName, basePath, size string) (err error)
	SetTimeWithNtpServers(servers []string, serversFilePath string) (err error)
	SetupEphemeralDiskWithPath(devicePath, mountPoint string) (err error)
	MountPersistentDisk(devicePath, mountPoint string) (err error)
	UnmountPersistentDisk(devicePath string) (didUnmount bool, err error)
	MigratePersistentDisk(fromMountPoint, toMountPoint string) (err error)
	IsMountPoint(path string) (result bool, err error)
	IsDevicePathMounted(path string) (result bool, err error)
	StartMonit() (err error)
	SetupMonitUser() (err error)
	GetMonitCredentials() (username, password string, err error)
}
