package platform

import (
	"bytes"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"text/template"
	"time"

	bosherr "bosh/errors"
	boshdpresolv "bosh/infrastructure/devicepathresolver"
	boshlog "bosh/logger"
	boshcd "bosh/platform/cdutil"
	boshcmd "bosh/platform/commands"
	boshdisk "bosh/platform/disk"
	boshnet "bosh/platform/net"
	boshstats "bosh/platform/stats"
	boshvitals "bosh/platform/vitals"
	boshsettings "bosh/settings"
	boshdir "bosh/settings/directories"
	boshdirs "bosh/settings/directories"
	boshsys "bosh/system"
)

type LinuxOptions struct {
	// When set to true loop back device
	// is not going to be overlayed over /tmp to limit /tmp dir size
	UseDefaultTmpDir bool

	// When set to true persistent disk will be assumed to be pre-formatted;
	// otherwise agent will partition and format it right before mounting
	UsePreformattedPersistentDisk bool

	// When set to true persistent disk will be mounted as a bind-mount
	BindMountPersistentDisk bool
}

type linux struct {
	fs                 boshsys.FileSystem
	cmdRunner          boshsys.CmdRunner
	collector          boshstats.StatsCollector
	compressor         boshcmd.Compressor
	copier             boshcmd.Copier
	dirProvider        boshdirs.DirectoriesProvider
	vitalsService      boshvitals.Service
	cdutil             boshcd.CdUtil
	diskManager        boshdisk.Manager
	netManager         boshnet.NetManager
	diskScanDuration   time.Duration
	devicePathResolver boshdpresolv.DevicePathResolver
	options            LinuxOptions
	logger             boshlog.Logger
}

func NewLinuxPlatform(
	fs boshsys.FileSystem,
	cmdRunner boshsys.CmdRunner,
	collector boshstats.StatsCollector,
	compressor boshcmd.Compressor,
	copier boshcmd.Copier,
	dirProvider boshdirs.DirectoriesProvider,
	vitalsService boshvitals.Service,
	cdutil boshcd.CdUtil,
	diskManager boshdisk.Manager,
	netManager boshnet.NetManager,
	diskScanDuration time.Duration,
	options LinuxOptions,
	logger boshlog.Logger,
) (platform *linux) {
	platform = &linux{
		fs:               fs,
		cmdRunner:        cmdRunner,
		collector:        collector,
		compressor:       compressor,
		copier:           copier,
		dirProvider:      dirProvider,
		vitalsService:    vitalsService,
		cdutil:           cdutil,
		diskManager:      diskManager,
		netManager:       netManager,
		diskScanDuration: diskScanDuration,
		options:          options,
		logger:           logger,
	}
	return
}

func (p linux) GetFs() (fs boshsys.FileSystem) {
	return p.fs
}

func (p linux) GetRunner() (runner boshsys.CmdRunner) {
	return p.cmdRunner
}

func (p linux) GetCompressor() (runner boshcmd.Compressor) {
	return p.compressor
}

func (p linux) GetCopier() (runner boshcmd.Copier) {
	return p.copier
}

func (p linux) GetDirProvider() (dirProvider boshdir.DirectoriesProvider) {
	return p.dirProvider
}

func (p linux) GetVitalsService() (service boshvitals.Service) {
	return p.vitalsService
}

func (p linux) GetFileContentsFromCDROM(fileName string) (contents []byte, err error) {
	return p.cdutil.GetFileContents(fileName)
}

func (p linux) GetDevicePathResolver() (devicePathResolver boshdpresolv.DevicePathResolver) {
	return p.devicePathResolver
}

func (p *linux) SetDevicePathResolver(devicePathResolver boshdpresolv.DevicePathResolver) (err error) {
	p.devicePathResolver = devicePathResolver
	return
}

func (p linux) SetupManualNetworking(networks boshsettings.Networks) (err error) {
	return p.netManager.SetupManualNetworking(networks, nil)
}

func (p linux) SetupDhcp(networks boshsettings.Networks) (err error) {
	return p.netManager.SetupDhcp(networks)
}

func (p linux) SetupRuntimeConfiguration() (err error) {
	_, _, _, err = p.cmdRunner.RunCommand("bosh-agent-rc")
	if err != nil {
		err = bosherr.WrapError(err, "Shelling out to bosh-agent-rc")
	}
	return
}

func (p linux) CreateUser(username, password, basePath string) (err error) {
	p.fs.MkdirAll(basePath, os.FileMode(0755))
	if err != nil {
		err = bosherr.WrapError(err, "Making user base path")
		return
	}

	args := []string{"-m", "-b", basePath, "-s", "/bin/bash"}

	if password != "" {
		args = append(args, "-p", password)
	}

	args = append(args, username)

	_, _, _, err = p.cmdRunner.RunCommand("useradd", args...)
	if err != nil {
		err = bosherr.WrapError(err, "Shelling out to useradd")
		return
	}
	return
}

func (p linux) AddUserToGroups(username string, groups []string) (err error) {
	_, _, _, err = p.cmdRunner.RunCommand("usermod", "-G", strings.Join(groups, ","), username)
	if err != nil {
		err = bosherr.WrapError(err, "Shelling out to usermod")
	}
	return
}

func (p linux) DeleteEphemeralUsersMatching(reg string) (err error) {
	compiledReg, err := regexp.Compile(reg)
	if err != nil {
		err = bosherr.WrapError(err, "Compiling regexp")
		return
	}

	matchingUsers, err := p.findEphemeralUsersMatching(compiledReg)
	if err != nil {
		err = bosherr.WrapError(err, "Finding ephemeral users")
		return
	}

	for _, user := range matchingUsers {
		p.deleteUser(user)
	}
	return
}

func (p linux) deleteUser(user string) (err error) {
	_, _, _, err = p.cmdRunner.RunCommand("userdel", "-r", user)
	return
}

func (p linux) findEphemeralUsersMatching(reg *regexp.Regexp) (matchingUsers []string, err error) {
	passwd, err := p.fs.ReadFileString("/etc/passwd")
	if err != nil {
		err = bosherr.WrapError(err, "Reading /etc/passwd")
		return
	}

	for _, line := range strings.Split(passwd, "\n") {
		user := strings.Split(line, ":")[0]
		matchesPrefix := strings.HasPrefix(user, boshsettings.EphemeralUserPrefix)
		matchesReg := reg.MatchString(user)

		if matchesPrefix && matchesReg {
			matchingUsers = append(matchingUsers, user)
		}
	}
	return
}

func (p linux) SetupSsh(publicKey, username string) (err error) {
	homeDir, err := p.fs.HomeDir(username)
	if err != nil {
		err = bosherr.WrapError(err, "Finding home dir for user")
		return
	}

	sshPath := filepath.Join(homeDir, ".ssh")
	p.fs.MkdirAll(sshPath, os.FileMode(0700))
	p.fs.Chown(sshPath, username)

	authKeysPath := filepath.Join(sshPath, "authorized_keys")
	err = p.fs.WriteFileString(authKeysPath, publicKey)
	if err != nil {
		err = bosherr.WrapError(err, "Creating authorized_keys file")
		return
	}

	p.fs.Chown(authKeysPath, username)
	p.fs.Chmod(authKeysPath, os.FileMode(0600))

	return
}

func (p linux) SetUserPassword(user, encryptedPwd string) (err error) {
	_, _, _, err = p.cmdRunner.RunCommand("usermod", "-p", encryptedPwd, user)
	if err != nil {
		err = bosherr.WrapError(err, "Shelling out to usermod")
	}
	return
}

func (p linux) SetupHostname(hostname string) (err error) {
	_, _, _, err = p.cmdRunner.RunCommand("hostname", hostname)
	if err != nil {
		err = bosherr.WrapError(err, "Shelling out to hostname")
		return
	}

	err = p.fs.WriteFileString("/etc/hostname", hostname)
	if err != nil {
		err = bosherr.WrapError(err, "Writing /etc/hostname")
		return
	}

	buffer := bytes.NewBuffer([]byte{})
	t := template.Must(template.New("etc-hosts").Parse(etcHostsTemplate))

	err = t.Execute(buffer, hostname)
	if err != nil {
		err = bosherr.WrapError(err, "Generating config from template")
		return
	}

	err = p.fs.WriteFile("/etc/hosts", buffer.Bytes())
	if err != nil {
		err = bosherr.WrapError(err, "Writing to /etc/hosts")
	}
	return
}

const etcHostsTemplate = `127.0.0.1 localhost {{ . }}

# The following lines are desirable for IPv6 capable hosts
::1 localhost ip6-localhost ip6-loopback {{ . }}
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
ff02::3 ip6-allhosts
`

func (p linux) SetupLogrotate(groupName, basePath, size string) (err error) {
	buffer := bytes.NewBuffer([]byte{})
	t := template.Must(template.New("logrotate-d-config").Parse(etcLogrotateDTemplate))

	type logrotateArgs struct {
		BasePath string
		Size     string
	}

	err = t.Execute(buffer, logrotateArgs{basePath, size})
	if err != nil {
		err = bosherr.WrapError(err, "Generating logrotate config")
		return
	}

	err = p.fs.WriteFile(filepath.Join("/etc/logrotate.d", groupName), buffer.Bytes())
	if err != nil {
		err = bosherr.WrapError(err, "Writing to /etc/logrotate.d")
		return
	}

	return
}

// Logrotate config file - /etc/logrotate.d/<group-name>
const etcLogrotateDTemplate = `# Generated by bosh-agent

{{ .BasePath }}/data/sys/log/*.log {{ .BasePath }}/data/sys/log/*/*.log {{ .BasePath }}/data/sys/log/*/*/*.log {
  missingok
  rotate 7
  compress
  delaycompress
  copytruncate
  size={{ .Size }}
}
`

func (p linux) SetTimeWithNtpServers(servers []string) (err error) {
	serversFilePath := filepath.Join(p.dirProvider.BaseDir(), "/bosh/etc/ntpserver")
	if len(servers) == 0 {
		return
	}

	err = p.fs.WriteFileString(serversFilePath, strings.Join(servers, " "))
	if err != nil {
		err = bosherr.WrapError(err, "Writing to %s", serversFilePath)
		return
	}

	// Make a best effort to sync time now but don't error
	_, _, _, _ = p.cmdRunner.RunCommand("ntpdate")
	return
}

func (p linux) SetupEphemeralDiskWithPath(realPath string) error {
	mountPoint := p.dirProvider.DataDir()

	err := p.fs.MkdirAll(mountPoint, os.FileMode(0750))
	if err != nil {
		return bosherr.WrapError(err, "Creating data dir")
	}

	if realPath == "" {
		p.logger.Debug("platform", "Using root disk as ephemeral disk")
		return nil
	}

	swapSize, linuxSize, err := p.calculateEphemeralDiskPartitionSizes(realPath)
	if err != nil {
		return bosherr.WrapError(err, "Calculating partition sizes")
	}

	partitions := []boshdisk.Partition{
		{SizeInMb: swapSize, Type: boshdisk.PartitionTypeSwap},
		{SizeInMb: linuxSize, Type: boshdisk.PartitionTypeLinux},
	}

	err = p.diskManager.GetPartitioner().Partition(realPath, partitions)
	if err != nil {
		return bosherr.WrapError(err, "Partitioning disk")
	}

	swapPartitionPath := realPath + "1"
	dataPartitionPath := realPath + "2"
	err = p.diskManager.GetFormatter().Format(swapPartitionPath, boshdisk.FileSystemSwap)
	if err != nil {
		return bosherr.WrapError(err, "Formatting swap")
	}

	err = p.diskManager.GetFormatter().Format(dataPartitionPath, boshdisk.FileSystemExt4)
	if err != nil {
		return bosherr.WrapError(err, "Formatting data partition with ext4")
	}

	err = p.diskManager.GetMounter().SwapOn(swapPartitionPath)
	if err != nil {
		return bosherr.WrapError(err, "Mounting swap")
	}

	err = p.diskManager.GetMounter().Mount(dataPartitionPath, mountPoint)
	if err != nil {
		return bosherr.WrapError(err, "Mounting data partition")
	}

	return nil
}

func (p linux) SetupDataDir() error {
	dataDir := p.dirProvider.DataDir()

	sysDir := filepath.Join(dataDir, "sys")

	logDir := filepath.Join(sysDir, "log")
	err := p.fs.MkdirAll(logDir, os.FileMode(0750))
	if err != nil {
		return bosherr.WrapError(err, "Making %s dir", logDir)
	}

	_, _, _, err = p.cmdRunner.RunCommand("chown", "root:vcap", sysDir)
	if err != nil {
		return bosherr.WrapError(err, "chown %s", sysDir)
	}

	_, _, _, err = p.cmdRunner.RunCommand("chown", "root:vcap", logDir)
	if err != nil {
		return bosherr.WrapError(err, "chown %s", logDir)
	}

	runDir := filepath.Join(sysDir, "run")
	err = p.fs.MkdirAll(runDir, os.FileMode(0750))
	if err != nil {
		return bosherr.WrapError(err, "Making %s dir", runDir)
	}

	_, _, _, err = p.cmdRunner.RunCommand("chown", "root:vcap", runDir)
	if err != nil {
		return bosherr.WrapError(err, "chown %s", runDir)
	}

	return nil
}

func (p linux) SetupTmpDir() error {
	systemTmpDir := "/tmp"
	boshTmpDir := p.dirProvider.TmpDir()
	boshRootTmpPath := filepath.Join(p.dirProvider.DataDir(), "root_tmp")

	// 0755 to make sure that vcap user can use new temp dir
	err := p.fs.MkdirAll(boshTmpDir, os.FileMode(0755))
	if err != nil {
		return bosherr.WrapError(err, "Creating temp dir")
	}

	err = os.Setenv("TMPDIR", boshTmpDir)
	if err != nil {
		return bosherr.WrapError(err, "Setting TMPDIR")
	}

	err = p.changeTmpDirPermissions(systemTmpDir)
	if err != nil {
		return err
	}

	// /var/tmp is used for preserving temporary files between system reboots
	_, _, _, err = p.cmdRunner.RunCommand("chmod", "0700", "/var/tmp")
	if err != nil {
		return bosherr.WrapError(err, "chmod /var/tmp")
	}

	if p.options.UseDefaultTmpDir {
		return nil
	}

	systemTmpDirIsMounted, err := p.IsMountPoint(systemTmpDir)
	if err != nil {
		return bosherr.WrapError(err, "Checking for mount point %s", systemTmpDir)
	}

	if !systemTmpDirIsMounted {
		// If it's not mounted on /tmp, blow it away
		_, _, _, err = p.cmdRunner.RunCommand("truncate", "-s", "128M", boshRootTmpPath)
		if err != nil {
			return bosherr.WrapError(err, "Truncating root tmp dir")
		}

		_, _, _, err = p.cmdRunner.RunCommand("chmod", "0700", boshRootTmpPath)
		if err != nil {
			return bosherr.WrapError(err, "Chmoding root tmp dir")
		}

		_, _, _, err = p.cmdRunner.RunCommand("mke2fs", "-t", "ext4", "-m", "1", "-F", boshRootTmpPath)
		if err != nil {
			return bosherr.WrapError(err, "Creating root tmp dir filesystem")
		}

		err = p.diskManager.GetMounter().Mount(boshRootTmpPath, systemTmpDir, "-t", "ext4", "-o", "loop")
		if err != nil {
			return bosherr.WrapError(err, "Mounting root tmp dir over /tmp")
		}

		// Change permissions for new mount point
		err = p.changeTmpDirPermissions(systemTmpDir)
		if err != nil {
			return err
		}
	}

	return nil
}

func (p linux) changeTmpDirPermissions(path string) error {
	_, _, _, err := p.cmdRunner.RunCommand("chown", "root:vcap", path)
	if err != nil {
		return bosherr.WrapError(err, "chown %s", path)
	}

	_, _, _, err = p.cmdRunner.RunCommand("chmod", "0770", path)
	if err != nil {
		return bosherr.WrapError(err, "chmod %s", path)
	}

	return nil
}

func (p linux) MountPersistentDisk(devicePath, mountPoint string) error {
	p.logger.Debug("platform", "Mounting persistent disk %s at %s", devicePath, mountPoint)

	err := p.fs.MkdirAll(mountPoint, os.FileMode(0700))
	if err != nil {
		return bosherr.WrapError(err, "Creating directory %s", mountPoint)
	}

	realPath, err := p.devicePathResolver.GetRealDevicePath(devicePath)
	if err != nil {
		return bosherr.WrapError(err, "Getting real device path")
	}

	if !p.options.UsePreformattedPersistentDisk {
		partitions := []boshdisk.Partition{
			{Type: boshdisk.PartitionTypeLinux},
		}

		err = p.diskManager.GetPartitioner().Partition(realPath, partitions)
		if err != nil {
			return bosherr.WrapError(err, "Partitioning disk")
		}

		partitionPath := realPath + "1"

		err = p.diskManager.GetFormatter().Format(partitionPath, boshdisk.FileSystemExt4)
		if err != nil {
			return bosherr.WrapError(err, "Formatting partition with ext4")
		}

		realPath = partitionPath
	}

	err = p.diskManager.GetMounter().Mount(realPath, mountPoint)
	if err != nil {
		return bosherr.WrapError(err, "Mounting partition")
	}

	return nil
}

func (p linux) UnmountPersistentDisk(devicePath string) (bool, error) {
	p.logger.Debug("platform", "Unmounting persistent disk %s", devicePath)

	realPath, err := p.devicePathResolver.GetRealDevicePath(devicePath)
	if err != nil {
		return false, bosherr.WrapError(err, "Getting real device path")
	}

	if !p.options.UsePreformattedPersistentDisk {
		realPath += "1"
	}

	return p.diskManager.GetMounter().Unmount(realPath)
}

func (p linux) NormalizeDiskPath(devicePath string) (string, bool) {
	realPath, err := p.devicePathResolver.GetRealDevicePath(devicePath)
	if err == nil {
		return realPath, true
	}

	return "", false
}

func (p linux) IsMountPoint(path string) (bool, error) {
	return p.diskManager.GetMounter().IsMountPoint(path)
}

func (p linux) MigratePersistentDisk(fromMountPoint, toMountPoint string) (err error) {
	p.logger.Debug("platform", "Migrating persistent disk %v to %v", fromMountPoint, toMountPoint)

	err = p.diskManager.GetMounter().RemountAsReadonly(fromMountPoint)
	if err != nil {
		err = bosherr.WrapError(err, "Remounting persistent disk as readonly")
		return
	}

	// Golang does not implement a file copy that would allow us to preserve dates...
	// So we have to shell out to tar to perform the copy instead of delegating to the FileSystem
	tarCopy := fmt.Sprintf("(tar -C %s -cf - .) | (tar -C %s -xpf -)", fromMountPoint, toMountPoint)
	_, _, _, err = p.cmdRunner.RunCommand("sh", "-c", tarCopy)
	if err != nil {
		err = bosherr.WrapError(err, "Copying files from old disk to new disk")
		return
	}

	_, err = p.diskManager.GetMounter().Unmount(fromMountPoint)
	if err != nil {
		err = bosherr.WrapError(err, "Unmounting old persistent disk")
		return
	}

	err = p.diskManager.GetMounter().Remount(toMountPoint, fromMountPoint)
	if err != nil {
		err = bosherr.WrapError(err, "Remounting new disk on original mountpoint")
	}
	return
}

func (p linux) IsPersistentDiskMounted(path string) (bool, error) {
	realPath, err := p.devicePathResolver.GetRealDevicePath(path)
	if err != nil {
		return false, bosherr.WrapError(err, "Getting real device path")
	}

	if !p.options.UsePreformattedPersistentDisk {
		realPath += "1"
	}

	return p.diskManager.GetMounter().IsMounted(realPath)
}

func (p linux) StartMonit() error {
	_, _, _, err := p.cmdRunner.RunCommand("sv", "up", "monit")
	if err != nil {
		return bosherr.WrapError(err, "Shelling out to sv")
	}

	return nil
}

func (p linux) SetupMonitUser() error {
	monitUserFilePath := filepath.Join(p.dirProvider.BaseDir(), "monit", "monit.user")
	if !p.fs.FileExists(monitUserFilePath) {
		err := p.fs.WriteFileString(monitUserFilePath, "vcap:random-password")
		if err != nil {
			return bosherr.WrapError(err, "Writing monit user file")
		}
	}

	return nil
}

func (p linux) GetMonitCredentials() (username, password string, err error) {
	monitUserFilePath := filepath.Join(p.dirProvider.BaseDir(), "monit", "monit.user")
	credContent, err := p.fs.ReadFileString(monitUserFilePath)
	if err != nil {
		err = bosherr.WrapError(err, "Reading monit user file")
		return
	}

	credParts := strings.SplitN(credContent, ":", 2)
	if len(credParts) != 2 {
		err = bosherr.New("Malformated monit user file, expecting username and password separated by ':'")
		return
	}

	username = credParts[0]
	password = credParts[1]
	return
}

func (p linux) PrepareForNetworkingChange() error {
	err := p.fs.RemoveAll("/etc/udev/rules.d/70-persistent-net.rules")
	if err != nil {
		return bosherr.WrapError(err, "Removing network rules file")
	}

	return nil
}

func (p linux) GetDefaultNetwork() (boshsettings.Network, error) {
	return p.netManager.GetDefaultNetwork()
}

func (p linux) calculateEphemeralDiskPartitionSizes(devicePath string) (swapSize, linuxSize uint64, err error) {
	memStats, err := p.collector.GetMemStats()
	if err != nil {
		err = bosherr.WrapError(err, "Getting mem stats")
		return
	}

	totalMemInMb := memStats.Total / uint64(1024*1024)

	diskSizeInMb, err := p.diskManager.GetPartitioner().GetDeviceSizeInMb(devicePath)
	if err != nil {
		err = bosherr.WrapError(err, "Getting device size")
		return
	}

	if totalMemInMb > diskSizeInMb/2 {
		swapSize = diskSizeInMb / 2
	} else {
		swapSize = totalMemInMb
	}

	linuxSize = diskSizeInMb - swapSize
	return
}
