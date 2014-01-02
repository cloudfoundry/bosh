package platform

import (
	boshcmd "bosh/platform/commands"
	boshstats "bosh/platform/stats"
	boshvitals "bosh/platform/vitals"
	fakevitals "bosh/platform/vitals/fakes"
	boshsettings "bosh/settings"
	boshdir "bosh/settings/directories"
	boshsys "bosh/system"
	fakesys "bosh/system/fakes"
)

type dummyPlatform struct{}

func newDummyPlatform() (p dummyPlatform) {
	return
}

func (p dummyPlatform) GetFs() (fs boshsys.FileSystem) {
	return &fakesys.FakeFileSystem{}
}

func (p dummyPlatform) GetRunner() (runner boshsys.CmdRunner) {
	return &fakesys.FakeCmdRunner{}
}

func (p dummyPlatform) GetStatsCollector() (collector boshstats.StatsCollector) {
	return boshstats.NewDummyStatsCollector()
}

func (p dummyPlatform) GetCompressor() (compressor boshcmd.Compressor) {
	return boshcmd.DummyCompressor{}
}

func (p dummyPlatform) GetDirProvider() (dirProvider boshdir.DirectoriesProvider) {
	return boshdir.NewDirectoriesProvider("/var/vcap")
}

func (p dummyPlatform) GetVitalsService() (service boshvitals.Service) {
	return fakevitals.NewFakeService()
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
