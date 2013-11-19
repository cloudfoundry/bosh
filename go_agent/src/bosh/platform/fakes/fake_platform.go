package fakes

import (
	boshstats "bosh/platform/stats"
	fakestats "bosh/platform/stats/fakes"
	boshsettings "bosh/settings"
	"os"
)

type FakePlatform struct {
	FakeStatsCollector                   *fakestats.FakeStatsCollector
	SetupRuntimeConfigurationWasInvoked  bool
	CreateUserUsername                   string
	CreateUserPassword                   string
	CreateUserBasePath                   string
	AddUserToGroupsGroups                map[string][]string
	DeleteEphemeralUsersMatchingRegex    string
	SetupSshPublicKeys                   map[string]string
	SetupHostnameHostname                string
	SetupEphemeralDiskWithPathDevicePath string
	SetupEphemeralDiskWithPathMountPoint string
	StartMonitStarted                    bool
	UserPasswords                        map[string]string
	SetTimeWithNtpServersServers         []string
	SetTimeWithNtpServersServersFilePath string
	CompressFilesInDirTarball            *os.File
	CompressFilesInDirDir                string
	CompressFilesInDirFilters            []string
}

func NewFakePlatform() (platform *FakePlatform) {
	platform = new(FakePlatform)
	platform.FakeStatsCollector = &fakestats.FakeStatsCollector{}
	platform.AddUserToGroupsGroups = make(map[string][]string)
	platform.SetupSshPublicKeys = make(map[string]string)
	platform.UserPasswords = make(map[string]string)
	return
}

func (p *FakePlatform) GetStatsCollector() (collector boshstats.StatsCollector) {
	return p.FakeStatsCollector
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

func (p *FakePlatform) SetupHostname(hostname string) (err error) {
	p.SetupHostnameHostname = hostname
	return
}

func (p *FakePlatform) SetupDhcp(networks boshsettings.Networks) (err error) {
	return
}

func (p *FakePlatform) SetupEphemeralDiskWithPath(devicePath, mountPoint string) (err error) {
	p.SetupEphemeralDiskWithPathDevicePath = devicePath
	p.SetupEphemeralDiskWithPathMountPoint = mountPoint
	return
}

func (p *FakePlatform) StartMonit() (err error) {
	p.StartMonitStarted = true
	return
}

func (p *FakePlatform) SetUserPassword(user, encryptedPwd string) (err error) {
	p.UserPasswords[user] = encryptedPwd
	return
}

func (p *FakePlatform) SetTimeWithNtpServers(servers []string, serversFilePath string) (err error) {
	p.SetTimeWithNtpServersServers = servers
	p.SetTimeWithNtpServersServersFilePath = serversFilePath
	return
}

func (p *FakePlatform) CompressFilesInDir(dir string, filters []string) (tarball *os.File, err error) {
	p.CompressFilesInDirDir = dir
	p.CompressFilesInDirFilters = filters

	tarball = p.CompressFilesInDirTarball
	return
}
