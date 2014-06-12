package fakes

import (
	boshdpresolv "bosh/infrastructure/devicepathresolver"
	fakedpresolv "bosh/infrastructure/devicepathresolver/fakes"
	boshlog "bosh/logger"
	boshcmd "bosh/platform/commands"
	fakecmd "bosh/platform/commands/fakes"
	boshvitals "bosh/platform/vitals"
	fakevitals "bosh/platform/vitals/fakes"
	boshsettings "bosh/settings"
	boshdir "bosh/settings/directories"
	boshsys "bosh/system"
	fakesys "bosh/system/fakes"
)

type FakePlatform struct {
	Fs                *fakesys.FakeFileSystem
	Runner            *fakesys.FakeCmdRunner
	FakeCompressor    *fakecmd.FakeCompressor
	FakeCopier        *fakecmd.FakeCopier
	FakeVitalsService *fakevitals.FakeService
	logger            boshlog.Logger

	DevicePathResolver boshdpresolv.DevicePathResolver

	SetupRuntimeConfigurationWasInvoked bool

	CreateUserUsername string
	CreateUserPassword string
	CreateUserBasePath string

	AddUserToGroupsGroups             map[string][]string
	DeleteEphemeralUsersMatchingRegex string
	SetupSshPublicKeys                map[string]string

	SetupSshCalled    bool
	SetupSshPublicKey string
	SetupSshUsername  string
	SetupSshErr       error

	UserPasswords         map[string]string
	SetupHostnameHostname string

	SetTimeWithNtpServersServers []string

	SetupEphemeralDiskWithPathDevicePath string
	SetupEphemeralDiskWithPathErr        error

	SetupDataDirCalled bool
	SetupDataDirErr    error

	SetupTmpDirCalled bool
	SetupTmpDirErr    error

	SetupManualNetworkingNetworks boshsettings.Networks

	SetupDhcpNetworks boshsettings.Networks
	SetupDhcpErr      error

	MountPersistentDiskCalled     bool
	MountPersistentDiskDevicePath string
	MountPersistentDiskMountPoint string
	MountPersistentDiskErr        error

	UnmountPersistentDiskDidUnmount bool
	UnmountPersistentDiskDevicePath string

	GetFileContentsFromCDROMPath     string
	GetFileContentsFromCDROMContents []byte

	NormalizeDiskPathCalled   bool
	NormalizeDiskPathPath     string
	NormalizeDiskPathFound    bool
	NormalizeDiskPathRealPath string

	ScsiDiskMap map[string]string

	MigratePersistentDiskFromMountPoint string
	MigratePersistentDiskToMountPoint   string

	IsMountPointPath   string
	IsMountPointResult bool
	IsMountPointErr    error

	MountedDevicePaths []string

	StartMonitStarted           bool
	SetupMonitUserSetup         bool
	GetMonitCredentialsUsername string
	GetMonitCredentialsPassword string

	PrepareForNetworkingChangeCalled bool
	PrepareForNetworkingChangeErr    error

	GetDefaultNetworkCalled  bool
	GetDefaultNetworkNetwork boshsettings.Network
	GetDefaultNetworkErr     error
}

func NewFakePlatform() (platform *FakePlatform) {
	platform = new(FakePlatform)
	platform.Fs = fakesys.NewFakeFileSystem()
	platform.Runner = fakesys.NewFakeCmdRunner()
	platform.FakeCompressor = fakecmd.NewFakeCompressor()
	platform.FakeCopier = fakecmd.NewFakeCopier()
	platform.FakeVitalsService = fakevitals.NewFakeService()
	platform.DevicePathResolver = fakedpresolv.NewFakeDevicePathResolver()
	platform.AddUserToGroupsGroups = make(map[string][]string)
	platform.SetupSshPublicKeys = make(map[string]string)
	platform.UserPasswords = make(map[string]string)
	platform.ScsiDiskMap = make(map[string]string)
	return
}

func (p *FakePlatform) GetFs() (fs boshsys.FileSystem) {
	return p.Fs
}

func (p *FakePlatform) GetRunner() (runner boshsys.CmdRunner) {
	return p.Runner
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

func (p *FakePlatform) GetDevicePathResolver() (devicePathResolver boshdpresolv.DevicePathResolver) {
	return p.DevicePathResolver
}

func (p *FakePlatform) SetDevicePathResolver(devicePathResolver boshdpresolv.DevicePathResolver) (err error) {
	p.DevicePathResolver = devicePathResolver
	return
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

func (p *FakePlatform) SetupSsh(publicKey, username string) error {
	p.SetupSshCalled = true
	p.SetupSshPublicKeys[username] = publicKey
	p.SetupSshPublicKey = publicKey
	p.SetupSshUsername = username
	return p.SetupSshErr
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
	p.SetupDhcpNetworks = networks
	return p.SetupDhcpErr
}

func (p *FakePlatform) SetupManualNetworking(networks boshsettings.Networks) (err error) {
	p.SetupManualNetworkingNetworks = networks
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
	return p.SetupEphemeralDiskWithPathErr
}

func (p *FakePlatform) SetupDataDir() error {
	p.SetupDataDirCalled = true
	return p.SetupDataDirErr
}

func (p *FakePlatform) SetupTmpDir() error {
	p.SetupTmpDirCalled = true
	return p.SetupTmpDirErr
}

func (p *FakePlatform) MountPersistentDisk(devicePath, mountPoint string) (err error) {
	p.MountPersistentDiskCalled = true
	p.MountPersistentDiskDevicePath = devicePath
	p.MountPersistentDiskMountPoint = mountPoint
	return p.MountPersistentDiskErr
}

func (p *FakePlatform) UnmountPersistentDisk(devicePath string) (didUnmount bool, err error) {
	p.UnmountPersistentDiskDevicePath = devicePath
	didUnmount = p.UnmountPersistentDiskDidUnmount
	return
}

func (p *FakePlatform) NormalizeDiskPath(devicePath string) (realPath string, found bool) {
	p.NormalizeDiskPathCalled = true
	p.NormalizeDiskPathPath = devicePath
	realPath = p.NormalizeDiskPathRealPath
	found = p.NormalizeDiskPathFound
	return
}

func (p *FakePlatform) GetFileContentsFromCDROM(path string) (contents []byte, err error) {
	p.GetFileContentsFromCDROMPath = path
	contents = p.GetFileContentsFromCDROMContents
	return
}

func (p *FakePlatform) MigratePersistentDisk(fromMountPoint, toMountPoint string) (err error) {
	p.MigratePersistentDiskFromMountPoint = fromMountPoint
	p.MigratePersistentDiskToMountPoint = toMountPoint
	return
}

func (p *FakePlatform) IsMountPoint(path string) (bool, error) {
	p.IsMountPointPath = path
	return p.IsMountPointResult, p.IsMountPointErr
}

func (p *FakePlatform) IsPersistentDiskMounted(path string) (result bool, err error) {
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

func (p *FakePlatform) PrepareForNetworkingChange() error {
	p.PrepareForNetworkingChangeCalled = true
	return p.PrepareForNetworkingChangeErr
}

func (p *FakePlatform) GetDefaultNetwork() (boshsettings.Network, error) {
	p.GetDefaultNetworkCalled = true
	return p.GetDefaultNetworkNetwork, p.GetDefaultNetworkErr
}
