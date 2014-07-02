package platform

import (
	boshdpresolv "bosh/infrastructure/devicepathresolver"
	boshcmd "bosh/platform/commands"
	boshvitals "bosh/platform/vitals"
	boshsettings "bosh/settings"
	boshdir "bosh/settings/directories"
	boshsys "bosh/system"
)

type Platform interface {
	GetFs() (fs boshsys.FileSystem)
	GetRunner() (runner boshsys.CmdRunner)
	GetCompressor() (compressor boshcmd.Compressor)
	GetCopier() (copier boshcmd.Copier)
	GetDirProvider() (dirProvider boshdir.DirectoriesProvider)
	GetVitalsService() (service boshvitals.Service)

	GetDevicePathResolver() (devicePathResolver boshdpresolv.DevicePathResolver)
	SetDevicePathResolver(devicePathResolver boshdpresolv.DevicePathResolver) (err error)

	// User management
	CreateUser(username, password, basePath string) (err error)
	AddUserToGroups(username string, groups []string) (err error)
	DeleteEphemeralUsersMatching(regex string) (err error)

	// Bootstrap functionality
	SetupSSH(publicKey, username string) (err error)
	SetUserPassword(user, encryptedPwd string) (err error)
	SetupHostname(hostname string) (err error)
	SetupDhcp(networks boshsettings.Networks) (err error)
	SetupManualNetworking(networks boshsettings.Networks) (err error)
	SetupLogrotate(groupName, basePath, size string) (err error)
	SetTimeWithNtpServers(servers []string) (err error)
	SetupEphemeralDiskWithPath(devicePath string) (err error)
	SetupDataDir() (err error)
	SetupTmpDir() (err error)
	SetupMonitUser() (err error)
	StartMonit() (err error)
	SetupRuntimeConfiguration() (err error)

	// Disk management
	MountPersistentDisk(devicePath, mountPoint string) error
	UnmountPersistentDisk(devicePath string) (didUnmount bool, err error)
	MigratePersistentDisk(fromMountPoint, toMountPoint string) (err error)
	NormalizeDiskPath(devicePath string) (realPath string, found bool)
	IsMountPoint(path string) (result bool, err error)
	IsPersistentDiskMounted(path string) (result bool, err error)

	GetFileContentsFromCDROM(filePath string) (contents []byte, err error)

	GetDefaultNetwork() (boshsettings.Network, error)

	// Additional monit management
	GetMonitCredentials() (username, password string, err error)
}
