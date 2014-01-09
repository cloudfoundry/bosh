package fakes

import (
	boshcmd "bosh/platform/commands"
	fakecmd "bosh/platform/commands/fakes"
	boshstats "bosh/platform/stats"
	fakestats "bosh/platform/stats/fakes"
	boshvitals "bosh/platform/vitals"
	fakevitals "bosh/platform/vitals/fakes"
	boshsettings "bosh/settings"
	boshdir "bosh/settings/directories"
	boshsys "bosh/system"
	fakesys "bosh/system/fakes"
)

type FakePlatform struct {
	Fs                 *fakesys.FakeFileSystem
	Runner             *fakesys.FakeCmdRunner
	FakeStatsCollector *fakestats.FakeStatsCollector
	FakeCompressor     *fakecmd.FakeCompressor
	FakeCopier         *fakecmd.FakeCopier
	FakeVitalsService  *fakevitals.FakeService

	SetupRuntimeConfigurationWasInvoked bool

	CreateUserUsername string
	CreateUserPassword string
	CreateUserBasePath string

	AddUserToGroupsGroups             map[string][]string
	DeleteEphemeralUsersMatchingRegex string
	SetupSshPublicKeys                map[string]string
	UserPasswords                     map[string]string
	SetupHostnameHostname             string

	SetTimeWithNtpServersServers []string

	SetupEphemeralDiskWithPathDevicePath string

	MountPersistentDiskDevicePath string
	MountPersistentDiskMountPoint string

	UnmountPersistentDiskDidUnmount bool
	UnmountPersistentDiskDevicePath string

	MigratePersistentDiskFromMountPoint string
	MigratePersistentDiskToMountPoint   string

	IsMountPointResult bool
	IsMountPointPath   string

	MountedDevicePaths []string

	StartMonitStarted           bool
	SetupMonitUserSetup         bool
	GetMonitCredentialsUsername string
	GetMonitCredentialsPassword string
}

func NewFakePlatform() (platform *FakePlatform) {
	platform = new(FakePlatform)
	platform.Fs = &fakesys.FakeFileSystem{}
	platform.Runner = &fakesys.FakeCmdRunner{}
	platform.FakeStatsCollector = &fakestats.FakeStatsCollector{}
	platform.FakeCompressor = fakecmd.NewFakeCompressor()
	platform.FakeCopier = fakecmd.NewFakeCopier()
	platform.FakeVitalsService = fakevitals.NewFakeService()

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

func (p *FakePlatform) GetCompressor() (compressor boshcmd.Compressor) {
	return p.FakeCompressor
}

func (p *FakePlatform) GetCopier() (copier boshcmd.Copier) {
	return p.FakeCopier
}

func (p *FakePlatform) GetDirProvider() (dirProvider boshdir.DirectoriesProvider) {
	return boshdir.NewDirectoriesProvider("/var/vcap")
}

func (p *FakePlatform) GetVitalsService() (service boshvitals.Service) {
	return p.FakeVitalsService
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
	return
}

func (p *FakePlatform) SetTimeWithNtpServers(servers []string) (err error) {
	p.SetTimeWithNtpServersServers = servers
	return
}

func (p *FakePlatform) SetupEphemeralDiskWithPath(devicePath string) (err error) {
	p.SetupEphemeralDiskWithPathDevicePath = devicePath
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

func (p *FakePlatform) IsDevicePathMounted(path string) (result bool, err error) {
	for _, mountedPath := range p.MountedDevicePaths {
		if mountedPath == path {
			return true, nil
		}
	}
	return
}

func (p *FakePlatform) StartMonit() (err error) {
	p.StartMonitStarted = true
	return
}

func (p *FakePlatform) SetupMonitUser() (err error) {
	p.SetupMonitUserSetup = true
	return
}

func (p *FakePlatform) GetMonitCredentials() (username, password string, err error) {
	username = p.GetMonitCredentialsUsername
	password = p.GetMonitCredentialsPassword
	return
}
