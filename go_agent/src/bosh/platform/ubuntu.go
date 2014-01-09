package platform

import (
	bosherr "bosh/errors"
	boshcmd "bosh/platform/commands"
	boshdisk "bosh/platform/disk"
	boshstats "bosh/platform/stats"
	boshvitals "bosh/platform/vitals"
	boshsettings "bosh/settings"
	boshdir "bosh/settings/directories"
	boshdirs "bosh/settings/directories"
	boshsys "bosh/system"
	"bytes"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"text/template"
	"time"
)

type ubuntu struct {
	collector       boshstats.StatsCollector
	fs              boshsys.FileSystem
	cmdRunner       boshsys.CmdRunner
	partitioner     boshdisk.Partitioner
	formatter       boshdisk.Formatter
	mounter         boshdisk.Mounter
	compressor      boshcmd.Compressor
	copier          boshcmd.Copier
	diskWaitTimeout time.Duration
	dirProvider     boshdirs.DirectoriesProvider
	vitalsService   boshvitals.Service
}

func newUbuntuPlatform(
	collector boshstats.StatsCollector,
	fs boshsys.FileSystem,
	cmdRunner boshsys.CmdRunner,
	diskManager boshdisk.Manager,
	dirProvider boshdirs.DirectoriesProvider,
) (platform ubuntu) {
	platform.collector = collector
	platform.fs = fs
	platform.cmdRunner = cmdRunner
	platform.dirProvider = dirProvider

	platform.partitioner = diskManager.GetPartitioner()
	platform.formatter = diskManager.GetFormatter()
	platform.mounter = diskManager.GetMounter()
	platform.diskWaitTimeout = 3 * time.Minute

	platform.compressor = boshcmd.NewTarballCompressor(cmdRunner, fs)
	platform.copier = boshcmd.NewCpCopier(cmdRunner, fs)
	platform.vitalsService = boshvitals.NewService(collector, dirProvider)
	return
}

func (p ubuntu) GetFs() (fs boshsys.FileSystem) {
	return p.fs
}

func (p ubuntu) GetRunner() (runner boshsys.CmdRunner) {
	return p.cmdRunner
}

func (p ubuntu) GetStatsCollector() (statsCollector boshstats.StatsCollector) {
	return p.collector
}

func (p ubuntu) GetCompressor() (runner boshcmd.Compressor) {
	return p.compressor
}

func (p ubuntu) GetCopier() (runner boshcmd.Copier) {
	return p.copier
}

func (p ubuntu) GetDirProvider() (dirProvider boshdir.DirectoriesProvider) {
	return p.dirProvider
}

func (p ubuntu) GetVitalsService() (service boshvitals.Service) {
	return p.vitalsService
}

func (p ubuntu) SetupRuntimeConfiguration() (err error) {
	_, _, err = p.cmdRunner.RunCommand("bosh-agent-rc")
	if err != nil {
		err = bosherr.WrapError(err, "Shelling out to bosh-agent-rc")
	}
	return
}

func (p ubuntu) CreateUser(username, password, basePath string) (err error) {
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

	_, _, err = p.cmdRunner.RunCommand("useradd", args...)
	if err != nil {
		err = bosherr.WrapError(err, "Shelling out to useradd")
		return
	}
	return
}

func (p ubuntu) AddUserToGroups(username string, groups []string) (err error) {
	_, _, err = p.cmdRunner.RunCommand("usermod", "-G", strings.Join(groups, ","), username)
	if err != nil {
		err = bosherr.WrapError(err, "Shelling out to usermod")
	}
	return
}

func (p ubuntu) DeleteEphemeralUsersMatching(reg string) (err error) {
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

func (p ubuntu) deleteUser(user string) (err error) {
	_, _, err = p.cmdRunner.RunCommand("userdel", "-r", user)
	return
}

func (p ubuntu) findEphemeralUsersMatching(reg *regexp.Regexp) (matchingUsers []string, err error) {
	passwd, err := p.fs.ReadFile("/etc/passwd")
	if err != nil {
		err = bosherr.WrapError(err, "Reading /etc/passwd")
		return
	}

	for _, line := range strings.Split(passwd, "\n") {
		user := strings.Split(line, ":")[0]
		matchesPrefix := strings.HasPrefix(user, boshsettings.EPHEMERAL_USER_PREFIX)
		matchesReg := reg.MatchString(user)

		if matchesPrefix && matchesReg {
			matchingUsers = append(matchingUsers, user)
		}
	}
	return
}

func (p ubuntu) SetupSsh(publicKey, username string) (err error) {
	homeDir, err := p.fs.HomeDir(username)
	if err != nil {
		err = bosherr.WrapError(err, "Finding home dir for user")
		return
	}

	sshPath := filepath.Join(homeDir, ".ssh")
	p.fs.MkdirAll(sshPath, os.FileMode(0700))
	p.fs.Chown(sshPath, username)

	authKeysPath := filepath.Join(sshPath, "authorized_keys")
	_, err = p.fs.WriteToFile(authKeysPath, publicKey)
	if err != nil {
		err = bosherr.WrapError(err, "Creating authorized_keys file")
		return
	}

	p.fs.Chown(authKeysPath, username)
	p.fs.Chmod(authKeysPath, os.FileMode(0600))

	return
}

func (p ubuntu) SetUserPassword(user, encryptedPwd string) (err error) {
	_, _, err = p.cmdRunner.RunCommand("usermod", "-p", encryptedPwd, user)
	if err != nil {
		err = bosherr.WrapError(err, "Shelling out to usermod")
	}
	return
}

func (p ubuntu) SetupHostname(hostname string) (err error) {
	_, _, err = p.cmdRunner.RunCommand("hostname", hostname)
	if err != nil {
		err = bosherr.WrapError(err, "Shelling out to hostname")
		return
	}

	_, err = p.fs.WriteToFile("/etc/hostname", hostname)
	if err != nil {
		err = bosherr.WrapError(err, "Writing /etc/hostname")
		return
	}

	buffer := bytes.NewBuffer([]byte{})
	t := template.Must(template.New("etc-hosts").Parse(ETC_HOSTS_TEMPLATE))

	err = t.Execute(buffer, hostname)
	if err != nil {
		err = bosherr.WrapError(err, "Generating config from template")
		return
	}

	_, err = p.fs.WriteToFile("/etc/hosts", buffer.String())
	if err != nil {
		err = bosherr.WrapError(err, "Writing to /etc/hosts")
	}
	return
}

const ETC_HOSTS_TEMPLATE = `127.0.0.1 localhost {{ . }}

# The following lines are desirable for IPv6 capable hosts
::1 localhost ip6-localhost ip6-loopback {{ . }}
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
ff02::3 ip6-allhosts
`

func (p ubuntu) SetupDhcp(networks boshsettings.Networks) (err error) {
	dnsServers := []string{}
	dnsNetwork, found := networks.DefaultNetworkFor("dns")
	if found {
		for i := len(dnsNetwork.Dns) - 1; i >= 0; i-- {
			dnsServers = append(dnsServers, dnsNetwork.Dns[i])
		}
	}

	type dhcpConfigArg struct {
		DnsServers []string
	}

	buffer := bytes.NewBuffer([]byte{})
	t := template.Must(template.New("dhcp-config").Parse(DHCP_CONFIG_TEMPLATE))

	err = t.Execute(buffer, dhcpConfigArg{dnsServers})
	if err != nil {
		err = bosherr.WrapError(err, "Generating config from template")
		return
	}

	written, err := p.fs.WriteToFile("/etc/dhcp3/dhclient.conf", buffer.String())
	if err != nil {
		err = bosherr.WrapError(err, "Writing to /etc/dhcp3/dhclient.conf")
		return
	}

	if written {
		// Ignore errors here, just run the commands
		p.cmdRunner.RunCommand("pkill", "dhclient3")
		p.cmdRunner.RunCommand("/etc/init.d/networking", "restart")
	}

	return
}

// DHCP Config file - /etc/dhcp3/dhclient.conf
const DHCP_CONFIG_TEMPLATE = `# Generated by bosh-agent

option rfc3442-classless-static-routes code 121 = array of unsigned integer 8;

send host-name "<hostname>";

request subnet-mask, broadcast-address, time-offset, routers,
	domain-name, domain-name-servers, domain-search, host-name,
	netbios-name-servers, netbios-scope, interface-mtu,
	rfc3442-classless-static-routes, ntp-servers;

{{ range .DnsServers }}prepend domain-name-servers {{ . }};
{{ end }}`

func (p ubuntu) SetupLogrotate(groupName, basePath, size string) (err error) {
	buffer := bytes.NewBuffer([]byte{})
	t := template.Must(template.New("logrotate-d-config").Parse(ETC_LOGROTATE_D_TEMPLATE))

	type logrotateArgs struct {
		BasePath string
		Size     string
	}

	err = t.Execute(buffer, logrotateArgs{basePath, size})
	if err != nil {
		err = bosherr.WrapError(err, "Generating logrotate config")
		return
	}

	_, err = p.fs.WriteToFile(filepath.Join("/etc/logrotate.d", groupName), buffer.String())
	if err != nil {
		err = bosherr.WrapError(err, "Writing to /etc/logrotate.d")
		return
	}

	return
}

// Logrotate config file - /etc/logrotate.d/<group-name>
const ETC_LOGROTATE_D_TEMPLATE = `# Generated by bosh-agent

{{ .BasePath }}/data/sys/log/*.log {{ .BasePath }}/data/sys/log/*/*.log {{ .BasePath }}/data/sys/log/*/*/*.log {
  missingok
  rotate 7
  compress
  delaycompress
  copytruncate
  size={{ .Size }}
}
`

func (p ubuntu) SetTimeWithNtpServers(servers []string) (err error) {
	serversFilePath := filepath.Join(p.dirProvider.BaseDir(), "/bosh/etc/ntpserver")
	if len(servers) == 0 {
		return
	}

	_, _, err = p.cmdRunner.RunCommand("ntpdate", servers...)
	if err != nil {
		err = bosherr.WrapError(err, "Shelling out to ntpdate")
		return
	}

	_, err = p.fs.WriteToFile(serversFilePath, strings.Join(servers, " "))
	if err != nil {
		err = bosherr.WrapError(err, "Writing to %s", serversFilePath)
		return
	}
	return
}

func (p ubuntu) SetupEphemeralDiskWithPath(devicePath string) (err error) {
	mountPoint := filepath.Join(p.dirProvider.BaseDir(), "data")
	p.fs.MkdirAll(mountPoint, os.FileMode(0750))

	realPath, err := p.getRealDevicePath(devicePath)
	if err != nil {
		err = bosherr.WrapError(err, "Getting real device path")
		return
	}

	swapSize, linuxSize, err := p.calculateEphemeralDiskPartitionSizes(realPath)
	if err != nil {
		err = bosherr.WrapError(err, "Calculating partition sizes")
		return
	}

	partitions := []boshdisk.Partition{
		{SizeInMb: swapSize, Type: boshdisk.PartitionTypeSwap},
		{SizeInMb: linuxSize, Type: boshdisk.PartitionTypeLinux},
	}

	err = p.partitioner.Partition(realPath, partitions)
	if err != nil {
		err = bosherr.WrapError(err, "Partitioning disk")
		return
	}

	swapPartitionPath := realPath + "1"
	dataPartitionPath := realPath + "2"
	err = p.formatter.Format(swapPartitionPath, boshdisk.FileSystemSwap)
	if err != nil {
		err = bosherr.WrapError(err, "Formatting swap")
		return
	}

	err = p.formatter.Format(dataPartitionPath, boshdisk.FileSystemExt4)
	if err != nil {
		err = bosherr.WrapError(err, "Formatting data partition with ext4")
		return
	}

	err = p.mounter.SwapOn(swapPartitionPath)
	if err != nil {
		err = bosherr.WrapError(err, "Mounting swap")
		return
	}

	err = p.mounter.Mount(dataPartitionPath, mountPoint)
	if err != nil {
		err = bosherr.WrapError(err, "Mounting data partition")
		return
	}

	dir := filepath.Join(mountPoint, "sys", "log")
	err = p.fs.MkdirAll(dir, os.FileMode(0750))
	if err != nil {
		err = bosherr.WrapError(err, "Making %s dir", dir)
		return
	}

	dir = filepath.Join(mountPoint, "sys", "run")
	err = p.fs.MkdirAll(dir, os.FileMode(0750))
	if err != nil {
		err = bosherr.WrapError(err, "Making %s dir", dir)
		return
	}
	return
}

func (p ubuntu) MountPersistentDisk(devicePath, mountPoint string) (err error) {
	p.fs.MkdirAll(mountPoint, os.FileMode(0700))

	realPath, err := p.getRealDevicePath(devicePath)
	if err != nil {
		err = bosherr.WrapError(err, "Getting real device path")
		return
	}

	partitions := []boshdisk.Partition{
		{Type: boshdisk.PartitionTypeLinux},
	}

	err = p.partitioner.Partition(realPath, partitions)
	if err != nil {
		err = bosherr.WrapError(err, "Partitioning disk")
		return
	}

	partitionPath := realPath + "1"
	err = p.formatter.Format(partitionPath, boshdisk.FileSystemExt4)
	if err != nil {
		err = bosherr.WrapError(err, "Formatting partition with ext4")
		return
	}

	err = p.mounter.Mount(partitionPath, mountPoint)
	if err != nil {
		err = bosherr.WrapError(err, "Mounting partition")
		return
	}
	return
}

func (p ubuntu) UnmountPersistentDisk(devicePath string) (didUnmount bool, err error) {
	realPath, err := p.getRealDevicePath(devicePath)
	if err != nil {
		err = bosherr.WrapError(err, "Getting real device path")
		return
	}

	return p.mounter.Unmount(realPath + "1")
}

func (p ubuntu) IsMountPoint(path string) (result bool, err error) {
	return p.mounter.IsMountPoint(path)
}

func (p ubuntu) MigratePersistentDisk(fromMountPoint, toMountPoint string) (err error) {
	err = p.mounter.RemountAsReadonly(fromMountPoint)
	if err != nil {
		err = bosherr.WrapError(err, "Remounting persistent disk as readonly")
		return
	}

	// Golang does not implement a file copy that would allow us to preserve dates...
	// So we have to shell out to tar to perform the copy instead of delegating to the FileSystem
	tarCopy := fmt.Sprintf("(tar -C %s -cf - .) | (tar -C %s -xpf -)", fromMountPoint, toMountPoint)
	_, _, err = p.cmdRunner.RunCommand("sh", "-c", tarCopy)
	if err != nil {
		err = bosherr.WrapError(err, "Copying files from old disk to new disk")
		return
	}

	_, err = p.mounter.Unmount(fromMountPoint)
	if err != nil {
		err = bosherr.WrapError(err, "Unmounting old persistent disk")
		return
	}

	err = p.mounter.Remount(toMountPoint, fromMountPoint)
	if err != nil {
		err = bosherr.WrapError(err, "Remounting new disk on original mountpoint")
	}
	return
}

func (p ubuntu) IsDevicePathMounted(path string) (result bool, err error) {
	realPath, err := p.getRealDevicePath(path)
	if err != nil {
		err = bosherr.WrapError(err, "Getting real device path")
		return
	}

	return p.mounter.IsMounted(realPath + "1")
}

func (p ubuntu) StartMonit() (err error) {
	_, _, err = p.cmdRunner.RunCommand("sv", "up", "monit")
	if err != nil {
		err = bosherr.WrapError(err, "Shelling out to sv")
	}
	return
}

func (p ubuntu) SetupMonitUser() (err error) {
	monitUserFilePath := filepath.Join(p.dirProvider.BaseDir(), "monit", "monit.user")
	if !p.fs.FileExists(monitUserFilePath) {
		_, err = p.fs.WriteToFile(monitUserFilePath, "vcap:random-password")
		if err != nil {
			err = bosherr.WrapError(err, "Writing monit user file")
		}
	}
	return
}

func (p ubuntu) GetMonitCredentials() (username, password string, err error) {
	monitUserFilePath := filepath.Join(p.dirProvider.BaseDir(), "monit", "monit.user")
	credContent, err := p.fs.ReadFile(monitUserFilePath)
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

func (p ubuntu) getRealDevicePath(devicePath string) (realPath string, err error) {
	stopAfter := time.Now().Add(p.diskWaitTimeout)

	realPath, found := p.findPossibleDevice(devicePath)
	for !found {
		if time.Now().After(stopAfter) {
			err = bosherr.New("Timed out getting real device path for %s", devicePath)
			return
		}
		time.Sleep(100 * time.Millisecond)
		realPath, found = p.findPossibleDevice(devicePath)
	}

	return
}

func (p ubuntu) findPossibleDevice(devicePath string) (realPath string, found bool) {
	pathSuffix := strings.Split(devicePath, "/dev/sd")[1]

	possiblePrefixes := []string{"/dev/xvd", "/dev/vd", "/dev/sd"}
	for _, prefix := range possiblePrefixes {
		path := prefix + pathSuffix
		if p.fs.FileExists(path) {
			realPath = path
			found = true
			return
		}
	}
	return
}

func (p ubuntu) calculateEphemeralDiskPartitionSizes(devicePath string) (swapSize, linuxSize uint64, err error) {
	memStats, err := p.collector.GetMemStats()
	if err != nil {
		err = bosherr.WrapError(err, "Getting mem stats")
		return
	}

	totalMemInMb := memStats.Total / uint64(1024*1024)

	diskSizeInMb, err := p.partitioner.GetDeviceSizeInMb(devicePath)
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
