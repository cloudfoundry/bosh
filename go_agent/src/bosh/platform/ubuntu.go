package platform

import (
	bosherr "bosh/errors"
	boshdisk "bosh/platform/disk"
	boshstats "bosh/platform/stats"
	boshsettings "bosh/settings"
	boshsys "bosh/system"
	"bytes"
	"errors"
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
	diskWaitTimeout time.Duration
}

func newUbuntuPlatform(collector boshstats.StatsCollector, fs boshsys.FileSystem, cmdRunner boshsys.CmdRunner, diskManager boshdisk.Manager) (platform ubuntu) {
	platform.collector = collector
	platform.fs = fs
	platform.cmdRunner = cmdRunner
	platform.partitioner = diskManager.GetPartitioner()
	platform.formatter = diskManager.GetFormatter()
	platform.mounter = diskManager.GetMounter()
	platform.diskWaitTimeout = 3 * time.Minute
	return
}

func (p ubuntu) GetStatsCollector() (statsCollector boshstats.StatsCollector) {
	return p.collector
}

func (p ubuntu) SetupRuntimeConfiguration() (err error) {
	_, _, err = p.cmdRunner.RunCommand("bosh-agent-rc")
	return
}

func (p ubuntu) CreateUser(username, password, basePath string) (err error) {
	p.fs.MkdirAll(basePath, os.FileMode(0755))

	args := []string{"-m", "-b", basePath, "-s", "/bin/bash"}

	if password != "" {
		args = append(args, "-p", password)
	}

	args = append(args, username)

	_, _, err = p.cmdRunner.RunCommand("useradd", args...)
	return
}

func (p ubuntu) AddUserToGroups(username string, groups []string) (err error) {
	_, _, err = p.cmdRunner.RunCommand("usermod", "-G", strings.Join(groups, ","), username)
	return
}

func (p ubuntu) DeleteEphemeralUsersMatching(reg string) (err error) {
	compiledReg, err := regexp.Compile(reg)
	if err != nil {
		return
	}

	matchingUsers, err := p.findEphemeralUsersMatching(compiledReg)
	if err != nil {
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
		return bosherr.WrapError(err, "Error finding home dir for user")
	}

	sshPath := filepath.Join(homeDir, ".ssh")
	p.fs.MkdirAll(sshPath, os.FileMode(0700))
	p.fs.Chown(sshPath, username)

	authKeysPath := filepath.Join(sshPath, "authorized_keys")
	_, err = p.fs.WriteToFile(authKeysPath, publicKey)
	if err != nil {
		return bosherr.WrapError(err, "Error creating authorized_keys file")
	}

	p.fs.Chown(authKeysPath, username)
	p.fs.Chmod(authKeysPath, os.FileMode(0600))

	return
}

func (p ubuntu) SetUserPassword(user, encryptedPwd string) (err error) {
	_, _, err = p.cmdRunner.RunCommand("usermod", "-p", encryptedPwd, user)
	return
}

func (p ubuntu) SetupHostname(hostname string) (err error) {
	_, _, err = p.cmdRunner.RunCommand("hostname", hostname)
	if err != nil {
		return
	}

	_, err = p.fs.WriteToFile("/etc/hostname", hostname)
	if err != nil {
		return
	}

	buffer := bytes.NewBuffer([]byte{})
	t := template.Must(template.New("etc-hosts").Parse(ETC_HOSTS_TEMPLATE))

	err = t.Execute(buffer, hostname)
	if err != nil {
		return
	}

	_, err = p.fs.WriteToFile("/etc/hosts", buffer.String())
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
		return
	}

	written, err := p.fs.WriteToFile("/etc/dhcp3/dhclient.conf", buffer.String())
	if err != nil {
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

func (p ubuntu) SetTimeWithNtpServers(servers []string, serversFilePath string) (err error) {
	if len(servers) == 0 {
		return
	}

	_, _, err = p.cmdRunner.RunCommand("ntpdate", servers...)
	if err != nil {
		return
	}

	_, err = p.fs.WriteToFile(serversFilePath, strings.Join(servers, " "))
	return
}

func (p ubuntu) SetupEphemeralDiskWithPath(devicePath, mountPoint string) (err error) {
	p.fs.MkdirAll(mountPoint, os.FileMode(0750))

	realPath, err := p.getRealDevicePath(devicePath)
	if err != nil {
		return
	}

	swapSize, linuxSize, err := p.calculateEphemeralDiskPartitionSizes(realPath)
	if err != nil {
		return
	}

	partitions := []boshdisk.Partition{
		{SizeInMb: swapSize, Type: boshdisk.PartitionTypeSwap},
		{SizeInMb: linuxSize, Type: boshdisk.PartitionTypeLinux},
	}

	err = p.partitioner.Partition(realPath, partitions)
	if err != nil {
		return
	}

	swapPartitionPath := realPath + "1"
	dataPartitionPath := realPath + "2"
	err = p.formatter.Format(swapPartitionPath, boshdisk.FileSystemSwap)
	if err != nil {
		return
	}

	err = p.formatter.Format(dataPartitionPath, boshdisk.FileSystemExt4)
	if err != nil {
		return
	}

	err = p.mounter.SwapOn(swapPartitionPath)
	if err != nil {
		return
	}

	err = p.mounter.Mount(dataPartitionPath, mountPoint)
	if err != nil {
		return
	}

	err = p.fs.MkdirAll(filepath.Join(mountPoint, "sys", "log"), os.FileMode(0750))
	if err != nil {
		return
	}

	err = p.fs.MkdirAll(filepath.Join(mountPoint, "sys", "run"), os.FileMode(0750))
	if err != nil {
		return
	}
	return
}

func (p ubuntu) StartMonit() (err error) {
	_, _, err = p.cmdRunner.RunCommand("sv", "up", "monit")
	return
}

func (p ubuntu) CompressFilesInDir(dir string, filters []string) (tarball *os.File, err error) {
	tmpDir := p.fs.TempDir()
	tgzDir := filepath.Join(tmpDir, "BoshAgentTarball")
	err = p.fs.MkdirAll(tgzDir, os.ModePerm)
	if err != nil {
		return
	}
	defer p.fs.RemoveAll(tgzDir)

	filesToCopy, err := p.findFilesMatchingFilters(dir, filters)
	if err != nil {
		return
	}

	for _, file := range filesToCopy {
		file = filepath.Clean(file)
		if !strings.HasPrefix(file, dir) {
			continue
		}

		relativePath := strings.Replace(file, dir, "", 1)
		dst := filepath.Join(tgzDir, relativePath)

		err = p.fs.MkdirAll(filepath.Dir(dst), os.ModePerm)
		if err != nil {
			return
		}

		// Golang does not have a way of copying files and preserving file info...
		_, _, err = p.cmdRunner.RunCommand("cp", "-p", file, dst)
		if err != nil {
			return
		}
	}

	tarballPath := filepath.Join(tmpDir, "files.tgz")
	os.Chdir(tgzDir)
	_, _, err = p.cmdRunner.RunCommand("tar", "czf", tarballPath, ".")
	if err != nil {
		return
	}

	tarball, err = p.fs.Open(tarballPath)
	return
}

func (p ubuntu) findFilesMatchingFilters(dir string, filters []string) (files []string, err error) {
	for _, filter := range filters {
		var newFiles []string

		newFiles, err = p.findFilesMatchingFilter(filepath.Join(dir, filter))
		if err != nil {
			return
		}

		files = append(files, newFiles...)
	}

	return
}

func (p ubuntu) findFilesMatchingFilter(filter string) (files []string, err error) {
	files, err = filepath.Glob(filter)
	if err != nil {
		return
	}

	// Ruby Dir.glob will include *.log when looking for **/*.log
	// Golang implementation will not do it automatically
	if strings.Contains(filter, "**/*") {
		var extraFiles []string

		updatedFilter := strings.Replace(filter, "**/*", "*", 1)
		extraFiles, err = p.findFilesMatchingFilter(updatedFilter)
		if err != nil {
			return
		}

		files = append(files, extraFiles...)
	}
	return
}

func (p ubuntu) getRealDevicePath(devicePath string) (realPath string, err error) {
	stopAfter := time.Now().Add(p.diskWaitTimeout)

	realPath, found := p.findPossibleDevice(devicePath)
	for !found {
		if time.Now().After(stopAfter) {
			err = errors.New(fmt.Sprintf("Timed out getting real device path for %s", devicePath))
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
		return
	}

	totalMemInMb := memStats.Total / uint64(1024*1024)

	diskSizeInMb, err := p.partitioner.GetDeviceSizeInMb(devicePath)
	if err != nil {
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
