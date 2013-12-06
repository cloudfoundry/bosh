package fakes

import (
	boshdisk "bosh/platform/disk"
	fakedisk "bosh/platform/disk/fakes"
	boshstats "bosh/platform/stats"
	fakestats "bosh/platform/stats/fakes"
	boshsettings "bosh/settings"
	boshsys "bosh/system"
	fakesys "bosh/system/fakes"
)

type FakePlatform struct {
	Fs                 *fakesys.FakeFileSystem
	Runner             *fakesys.FakeCmdRunner
	FakeStatsCollector *fakestats.FakeStatsCollector
	FakeCompressor     *fakedisk.FakeCompressor

	SetupRuntimeConfigurationWasInvoked bool

	CreateUserUsername string
	CreateUserPassword string
	CreateUserBasePath string

	AddUserToGroupsGroups             map[string][]string
	DeleteEphemeralUsersMatchingRegex string
	SetupSshPublicKeys                map[string]string
	UserPasswords                     map[string]string
	SetupHostnameHostname             string

	SetupLogrotateErr  error
	SetupLogrotateArgs SetupLogrotateArgs

	SetTimeWithNtpServersServers         []string
	SetTimeWithNtpServersServersFilePath string

	SetupEphemeralDiskWithPathDevicePath string
	SetupEphemeralDiskWithPathMountPoint string

	MountPersistentDiskDevicePath string
	MountPersistentDiskMountPoint string

	UnmountPersistentDiskDidUnmount bool
	UnmountPersistentDiskDevicePath string

	MigratePersistentDiskFromMountPoint string
	MigratePersistentDiskToMountPoint   string

	IsMountPointResult bool
	IsMountPointPath   string

	StartMonitStarted bool
}

type SetupLogrotateArgs struct {
	GroupName string
	BasePath  string
	Size      string
}

func NewFakePlatform() (platform *FakePlatform) {
	platform = new(FakePlatform)
	platform.Fs = &fakesys.FakeFileSystem{}
	platform.Runner = &fakesys.FakeCmdRunner{}
	platform.FakeStatsCollector = &fakestats.FakeStatsCollector{}
	platform.FakeCompressor = &fakedisk.FakeCompressor{}

	platform.AddUserToGroupsGroups = make(map[string][]string)
	platform.SetupSshPublicKeys = make(map[string]string)
	platform.UserPasswords = make(map[string]string)
	return
}

func (p *FakePlatform) GetFs() (fs boshsys.FileSystem) {
	return p.Fs
}

func (p *FakePlatform) GetRunner() (runner boshsys.CmdRunner) {
	return p.Runner
}

func (p *FakePlatform) GetStatsCollector() (collector boshstats.StatsCollector) {
	return p.FakeStatsCollector
}

func (p *FakePlatform) GetCompressor() (compressor boshdisk.Compressor) {
	return p.FakeCompressor
}

func (p *FakePlatform) SetupRuntimeConfiguration() (err error) {
	p.SetupRuntimeConfigurationWasInvoked = true
	return
}

func (p *FakePlatform) CreateUser(username, password, basePath string) (err error) {
	p.CreateUserUsername = username
	p.CreateUserPassword = password
	p.CreateUserBasePath = basePath
	return
}

func (p *FakePlatform) AddUserToGroups(username string, groups []string) (err error) {
	p.AddUserToGroupsGroups[username] = groups
	return
}

func (p *FakePlatform) DeleteEphemeralUsersMatching(regex string) (err error) {
	p.DeleteEphemeralUsersMatchingRegex = regex
	return
}

func (p *FakePlatform) SetupSsh(publicKey, username string) (err error) {
	p.SetupSshPublicKeys[username] = publicKey
	return
}

func (p *FakePlatform) SetUserPassword(user, encryptedPwd string) (err error) {
	p.UserPasswords[user] = encryptedPwd
	return
}

func (p *FakePlatform) SetupHostname(hostname string) (err error) {
	p.SetupHostnameHostname = hostname
	return
}

func (p *FakePlatform) SetupDhcp(networks boshsettings.Networks) (err error) {
	return
}

func (p *FakePlatform) SetupLogrotate(groupName, basePath, size string) (err error) {
	p.SetupLogrotateArgs = SetupLogrotateArgs{groupName, basePath, size}

	if p.SetupLogrotateErr != nil {
		err = p.SetupLogrotateErr
		return
	}

	return
}

func (p *FakePlatform) SetTimeWithNtpServers(servers []string, serversFilePath string) (err error) {
	p.SetTimeWithNtpServersServers = servers
	p.SetTimeWithNtpServersServersFilePath = serversFilePath
	return
}

func (p *FakePlatform) SetupEphemeralDiskWithPath(devicePath, mountPoint string) (err error) {
	p.SetupEphemeralDiskWithPathDevicePath = devicePath
	p.SetupEphemeralDiskWithPathMountPoint = mountPoint
	return
}

func (p *FakePlatform) MountPersistentDisk(devicePath, mountPoint string) (err error) {
	p.MountPersistentDiskDevicePath = devicePath
	p.MountPersistentDiskMountPoint = mountPoint
	return
}

func (p *FakePlatform) UnmountPersistentDisk(devicePath string) (didUnmount bool, err error) {
	p.UnmountPersistentDiskDevicePath = devicePath
	didUnmount = p.UnmountPersistentDiskDidUnmount
	return
}

func (p *FakePlatform) MigratePersistentDisk(fromMountPoint, toMountPoint string) (err error) {
	p.MigratePersistentDiskFromMountPoint = fromMountPoint
	p.MigratePersistentDiskToMountPoint = toMountPoint
	return
}

func (p *FakePlatform) IsMountPoint(path string) (result bool, err error) {
	p.IsMountPointPath = path
	result = p.IsMountPointResult
	return
}

func (p *FakePlatform) StartMonit() (err error) {
	p.StartMonitStarted = true
	return
}
