package platform

import (
	boshcmd "bosh/platform/commands"
	boshstats "bosh/platform/stats"
	boshvitals "bosh/platform/vitals"
	boshsettings "bosh/settings"
	boshdir "bosh/settings/directories"
	boshdirs "bosh/settings/directories"
	boshsys "bosh/system"
)

type dummyPlatform struct {
	collector     boshstats.StatsCollector
	fs            boshsys.FileSystem
	cmdRunner     boshsys.CmdRunner
	compressor    boshcmd.Compressor
	copier        boshcmd.Copier
	dirProvider   boshdirs.DirectoriesProvider
	vitalsService boshvitals.Service
}

func newDummyPlatform(
	collector boshstats.StatsCollector,
	fs boshsys.FileSystem,
	cmdRunner boshsys.CmdRunner,
	dirProvider boshdirs.DirectoriesProvider,
) (platform dummyPlatform) {
	platform.collector = collector
	platform.fs = fs
	platform.cmdRunner = cmdRunner
	platform.dirProvider = dirProvider

	platform.compressor = boshcmd.NewTarballCompressor(cmdRunner, fs)
	platform.copier = boshcmd.NewCpCopier(cmdRunner, fs)
	platform.vitalsService = boshvitals.NewService(collector, dirProvider)
	return
}

func (p dummyPlatform) GetFs() (fs boshsys.FileSystem) {
	return p.fs
}

func (p dummyPlatform) GetRunner() (runner boshsys.CmdRunner) {
	return p.cmdRunner
}

func (p dummyPlatform) GetStatsCollector() (collector boshstats.StatsCollector) {
	return p.collector
}

func (p dummyPlatform) GetCompressor() (compressor boshcmd.Compressor) {
	return p.compressor
}

func (p dummyPlatform) GetCopier() (copier boshcmd.Copier) {
	return p.copier
}

func (p dummyPlatform) GetDirProvider() (dirProvider boshdir.DirectoriesProvider) {
	return p.dirProvider
}

func (p dummyPlatform) GetVitalsService() (service boshvitals.Service) {
	return p.vitalsService
}

func (p dummyPlatform) SetupRuntimeConfiguration() (err error) {
	return
}

func (p dummyPlatform) CreateUser(username, password, basePath string) (err error) {
	return
}

func (p dummyPlatform) AddUserToGroups(username string, groups []string) (err error) {
	return
}

func (p dummyPlatform) DeleteEphemeralUsersMatching(regex string) (err error) {
	return
}

func (p dummyPlatform) SetupSsh(publicKey, username string) (err error) {
	return
}

func (p dummyPlatform) SetUserPassword(user, encryptedPwd string) (err error) {
	return
}

func (p dummyPlatform) SetupHostname(hostname string) (err error) {
	return
}

func (p dummyPlatform) SetupDhcp(networks boshsettings.Networks) (err error) {
	return
}

func (p dummyPlatform) SetupLogrotate(groupName, basePath, size string) (err error) {
	return
}

func (p dummyPlatform) SetTimeWithNtpServers(servers []string) (err error) {
	return
}

func (p dummyPlatform) SetupEphemeralDiskWithPath(devicePath string) (err error) {
	return
}

func (p dummyPlatform) MountPersistentDisk(devicePath, mountPoint string) (err error) {
	return
}

func (p dummyPlatform) UnmountPersistentDisk(devicePath string) (didUnmount bool, err error) {
	return
}

func (p dummyPlatform) MigratePersistentDisk(fromMountPoint, toMountPoint string) (err error) {
	return
}

func (p dummyPlatform) IsMountPoint(path string) (result bool, err error) {
	return
}

func (p dummyPlatform) IsDevicePathMounted(path string) (result bool, err error) {
	return
}

func (p dummyPlatform) StartMonit() (err error) {
	return
}

func (p dummyPlatform) SetupMonitUser() (err error) {
	return
}

func (p dummyPlatform) GetMonitCredentials() (username, password string, err error) {
	return
}
