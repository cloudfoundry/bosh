package platform

import (
	boshdisk "bosh/platform/disk"
	fakedisk "bosh/platform/disk/fakes"
	boshstats "bosh/platform/stats"
	boshsettings "bosh/settings"
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

func (p dummyPlatform) GetCompressor() (compressor boshdisk.Compressor) {
	return &fakedisk.FakeCompressor{}
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

func (p dummyPlatform) SetTimeWithNtpServers(servers []string, serversFilePath string) (err error) {
	return
}

func (p dummyPlatform) SetupEphemeralDiskWithPath(devicePath, mountPoint string) (err error) {
	return
}

func (p dummyPlatform) MountPersistentDisk(devicePath, mountPoint string) (err error) {
	return
}

func (p dummyPlatform) UnmountPersistentDisk(devicePath string) (didUnmount bool, err error) {
	return
}

func (p dummyPlatform) IsMountPoint(path string) (result bool, err error) {
	return
}

func (p dummyPlatform) StartMonit() (err error) {
	return
}
