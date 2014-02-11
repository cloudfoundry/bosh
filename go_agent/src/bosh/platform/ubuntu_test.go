package platform_test

import (
	. "bosh/platform"
	boshdisk "bosh/platform/disk"
	fakedisk "bosh/platform/disk/fakes"
	fakestats "bosh/platform/stats/fakes"
	boshsettings "bosh/settings"
	boshdirs "bosh/settings/directories"
	fakesys "bosh/system/fakes"
	"fmt"
	"github.com/stretchr/testify/assert"
	"os"
	"path/filepath"
	"testing"
	"time"
)

func TestUbuntuSetupRuntimeConfiguration(t *testing.T) {
	deps, ubuntu := buildUbuntu(1*time.Millisecond, 1*time.Millisecond)

	err := ubuntu.SetupRuntimeConfiguration()
	assert.NoError(t, err)

	assert.Equal(t, 1, len(deps.cmdRunner.RunCommands))
	assert.Equal(t, []string{"bosh-agent-rc"}, deps.cmdRunner.RunCommands[0])
}

func TestUbuntuCreateUser(t *testing.T) {
	expectedUseradd := []string{
		"useradd",
		"-m",
		"-b", "/some/path/to/home",
		"-s", "/bin/bash",
		"-p", "bar-pwd",
		"foo-user",
	}

	testUbuntuCreateUserWithPassword(t, "bar-pwd", expectedUseradd)
}

func TestUbuntuCreateUserWithAnEmptyPassword(t *testing.T) {
	expectedUseradd := []string{
		"useradd",
		"-m",
		"-b", "/some/path/to/home",
		"-s", "/bin/bash",
		"foo-user",
	}

	testUbuntuCreateUserWithPassword(t, "", expectedUseradd)
}

func testUbuntuCreateUserWithPassword(t *testing.T, password string, expectedUseradd []string) {
	deps, ubuntu := buildUbuntu(1*time.Millisecond, 1*time.Millisecond)

	err := ubuntu.CreateUser("foo-user", password, "/some/path/to/home")
	assert.NoError(t, err)

	basePathStat := deps.fs.GetFileTestStat("/some/path/to/home")
	assert.Equal(t, fakesys.FakeFileTypeDir, basePathStat.FileType)
	assert.Equal(t, os.FileMode(0755), basePathStat.FileMode)

	assert.Equal(t, 1, len(deps.cmdRunner.RunCommands))
	assert.Equal(t, expectedUseradd, deps.cmdRunner.RunCommands[0])
}

func TestUbuntuAddUserToGroups(t *testing.T) {
	deps, ubuntu := buildUbuntu(1*time.Millisecond, 1*time.Millisecond)

	err := ubuntu.AddUserToGroups("foo-user", []string{"group1", "group2", "group3"})
	assert.NoError(t, err)

	assert.Equal(t, 1, len(deps.cmdRunner.RunCommands))

	usermod := []string{"usermod", "-G", "group1,group2,group3", "foo-user"}
	assert.Equal(t, usermod, deps.cmdRunner.RunCommands[0])
}

func TestUbuntuDeleteUsersWithPrefixAndRegex(t *testing.T) {
	deps, ubuntu := buildUbuntu(1*time.Millisecond, 1*time.Millisecond)

	passwdFile := fmt.Sprintf(`%sfoo:...
%sbar:...
foo:...
bar:...
foobar:...
%sfoobar:...`,
		boshsettings.EPHEMERAL_USER_PREFIX, boshsettings.EPHEMERAL_USER_PREFIX, boshsettings.EPHEMERAL_USER_PREFIX,
	)

	deps.fs.WriteToFile("/etc/passwd", passwdFile)

	err := ubuntu.DeleteEphemeralUsersMatching("bar$")
	assert.NoError(t, err)
	assert.Equal(t, 2, len(deps.cmdRunner.RunCommands))
	assert.Equal(t, []string{"userdel", "-r", "bosh_bar"}, deps.cmdRunner.RunCommands[0])
	assert.Equal(t, []string{"userdel", "-r", "bosh_foobar"}, deps.cmdRunner.RunCommands[1])
}

func TestUbuntuSetupSsh(t *testing.T) {
	deps, ubuntu := buildUbuntu(1*time.Millisecond, 1*time.Millisecond)
	deps.fs.HomeDirHomePath = "/some/home/dir"

	ubuntu.SetupSsh("some public key", "vcap")

	sshDirPath := "/some/home/dir/.ssh"
	sshDirStat := deps.fs.GetFileTestStat(sshDirPath)

	assert.Equal(t, deps.fs.HomeDirUsername, "vcap")

	assert.NotNil(t, sshDirStat)
	assert.Equal(t, fakesys.FakeFileTypeDir, sshDirStat.FileType)
	assert.Equal(t, sshDirStat.FileMode, os.FileMode(0700))
	assert.Equal(t, sshDirStat.Username, "vcap")

	authKeysStat := deps.fs.GetFileTestStat(filepath.Join(sshDirPath, "authorized_keys"))

	assert.NotNil(t, authKeysStat)
	assert.Equal(t, authKeysStat.FileType, fakesys.FakeFileTypeFile)
	assert.Equal(t, authKeysStat.FileMode, os.FileMode(0600))
	assert.Equal(t, authKeysStat.Username, "vcap")
	assert.Equal(t, authKeysStat.Content, "some public key")
}

func TestUbuntuSetUserPassword(t *testing.T) {
	deps, ubuntu := buildUbuntu(1*time.Millisecond, 1*time.Millisecond)

	ubuntu.SetUserPassword("my-user", "my-encrypted-password")
	assert.Equal(t, 1, len(deps.cmdRunner.RunCommands))
	assert.Equal(t, []string{"usermod", "-p", "my-encrypted-password", "my-user"}, deps.cmdRunner.RunCommands[0])
}

func TestUbuntuSetupHostname(t *testing.T) {
	deps, ubuntu := buildUbuntu(1*time.Millisecond, 1*time.Millisecond)

	ubuntu.SetupHostname("foobar.local")
	assert.Equal(t, 1, len(deps.cmdRunner.RunCommands))
	assert.Equal(t, []string{"hostname", "foobar.local"}, deps.cmdRunner.RunCommands[0])

	hostnameFileContent, err := deps.fs.ReadFile("/etc/hostname")
	assert.NoError(t, err)
	assert.Equal(t, "foobar.local", hostnameFileContent)

	hostsFileContent, err := deps.fs.ReadFile("/etc/hosts")
	assert.NoError(t, err)
	assert.Equal(t, UBUNTU_EXPECTED_ETC_HOSTS, hostsFileContent)
}

const UBUNTU_EXPECTED_ETC_HOSTS = `127.0.0.1 localhost foobar.local

# The following lines are desirable for IPv6 capable hosts
::1 localhost ip6-localhost ip6-loopback foobar.local
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
ff02::3 ip6-allhosts
`

func TestUbuntuSetupDhcp(t *testing.T) {
	deps, ubuntu := buildUbuntu(1*time.Millisecond, 1*time.Millisecond)
	testUbuntuSetupDhcp(t, deps, ubuntu)

	assert.Equal(t, len(deps.cmdRunner.RunCommands), 2)
	assert.Equal(t, deps.cmdRunner.RunCommands[0], []string{"pkill", "dhclient3"})
	assert.Equal(t, deps.cmdRunner.RunCommands[1], []string{"/etc/init.d/networking", "restart"})
}

func TestUbuntuSetupDhcpWithPreExistingConfiguration(t *testing.T) {
	deps, ubuntu := buildUbuntu(1*time.Millisecond, 1*time.Millisecond)
	deps.fs.WriteToFile("/etc/dhcp3/dhclient.conf", UBUNTU_EXPECTED_DHCP_CONFIG)
	testUbuntuSetupDhcp(t, deps, ubuntu)

	assert.Equal(t, len(deps.cmdRunner.RunCommands), 0)
}

func testUbuntuSetupDhcp(t *testing.T,
	deps ubuntuDependencies,
	platform Platform) {
	networks := boshsettings.Networks{
		"bosh": boshsettings.Network{
			Default: []string{"dns"},
			Dns:     []string{"xx.xx.xx.xx", "yy.yy.yy.yy", "zz.zz.zz.zz"},
		},
		"vip": boshsettings.Network{
			Default: []string{},
			Dns:     []string{"aa.aa.aa.aa"},
		},
	}

	platform.SetupDhcp(networks)

	dhcpConfig := deps.fs.GetFileTestStat("/etc/dhcp3/dhclient.conf")
	assert.NotNil(t, dhcpConfig)
	assert.Equal(t, dhcpConfig.Content, UBUNTU_EXPECTED_DHCP_CONFIG)
}

const UBUNTU_EXPECTED_DHCP_CONFIG = `# Generated by bosh-agent

option rfc3442-classless-static-routes code 121 = array of unsigned integer 8;

send host-name "<hostname>";

request subnet-mask, broadcast-address, time-offset, routers,
	domain-name, domain-name-servers, domain-search, host-name,
	netbios-name-servers, netbios-scope, interface-mtu,
	rfc3442-classless-static-routes, ntp-servers;

prepend domain-name-servers zz.zz.zz.zz;
prepend domain-name-servers yy.yy.yy.yy;
prepend domain-name-servers xx.xx.xx.xx;
`

func TestUbuntuSetupManualNetworking(t *testing.T) {
	deps, ubuntu := buildUbuntu(1*time.Millisecond, 1*time.Millisecond)

	testUbuntuSetupManualNetworking(t, deps, ubuntu)

	time.Sleep(100 * time.Millisecond)

	assert.Equal(t, len(deps.cmdRunner.RunCommands), 8)
	assert.Equal(t, deps.cmdRunner.RunCommands[0], []string{"service", "network-interface", "stop", "INTERFACE=eth0"})
	assert.Equal(t, deps.cmdRunner.RunCommands[1], []string{"service", "network-interface", "start", "INTERFACE=eth0"})
	assert.Equal(t, deps.cmdRunner.RunCommands[2], []string{"arping", "-c", "1", "-U", "-I", "eth0", "192.168.195.6"})
	assert.Equal(t, deps.cmdRunner.RunCommands[7], []string{"arping", "-c", "1", "-U", "-I", "eth0", "192.168.195.6"})
}

func testUbuntuSetupManualNetworking(t *testing.T,
	deps ubuntuDependencies,
	platform Platform) {
	networks := boshsettings.Networks{
		"bosh": boshsettings.Network{
			Default: []string{"dns", "gateway"},
			Ip:      "192.168.195.6",
			Netmask: "255.255.255.0",
			Gateway: "192.168.195.1",
			Mac:     "22:00:0a:1f:ac:2a",
			Dns:     []string{"10.80.130.2", "10.80.130.1"},
		},
	}
	deps.fs.WriteToFile("/sys/class/net/eth0", "")
	deps.fs.WriteToFile("/sys/class/net/eth0/address", "22:00:0a:1f:ac:2a")
	deps.fs.GlobPaths = []string{"/sys/class/net/eth0"}

	platform.SetupManualNetworking(networks)

	networkConfig := deps.fs.GetFileTestStat("/etc/network/interfaces")
	assert.NotNil(t, networkConfig)
	assert.Equal(t, networkConfig.Content, UBUNTU_EXPECTED_NETWORK_INTERFACES)

	resolvConf := deps.fs.GetFileTestStat("/etc/resolv.conf")
	assert.NotNil(t, resolvConf)
	assert.Equal(t, resolvConf.Content, UBUNTU_EXPECTED_RESOLV_CONF)
}

const UBUNTU_EXPECTED_NETWORK_INTERFACES = `auto lo
iface lo inet loopback

auto eth0
iface eth0 inet static
    address 192.168.195.6
    network 192.168.195.0
    netmask 255.255.255.0
    broadcast 192.168.195.255
    gateway 192.168.195.1`

const UBUNTU_EXPECTED_RESOLV_CONF = `nameserver 10.80.130.1
nameserver 10.80.130.2
`

func TestUbuntuSetupLogrotate(t *testing.T) {
	deps, ubuntu := buildUbuntu(1*time.Millisecond, 1*time.Millisecond)

	ubuntu.SetupLogrotate("fake-group-name", "fake-base-path", "fake-size")

	logrotateFileContent, err := deps.fs.ReadFile("/etc/logrotate.d/fake-group-name")
	assert.NoError(t, err)
	assert.Equal(t, UBUNTU_EXPECTED_ETC_LOGROTATE, logrotateFileContent)
}

const UBUNTU_EXPECTED_ETC_LOGROTATE = `# Generated by bosh-agent

fake-base-path/data/sys/log/*.log fake-base-path/data/sys/log/*/*.log fake-base-path/data/sys/log/*/*/*.log {
  missingok
  rotate 7
  compress
  delaycompress
  copytruncate
  size=fake-size
}
`

func TestUbuntuSetTimeWithNtpServers(t *testing.T) {
	deps, ubuntu := buildUbuntu(1*time.Millisecond, 1*time.Millisecond)

	ubuntu.SetTimeWithNtpServers([]string{"0.north-america.pool.ntp.org", "1.north-america.pool.ntp.org"})

	ntpConfig := deps.fs.GetFileTestStat("/fake-dir/bosh/etc/ntpserver")
	assert.Equal(t, "0.north-america.pool.ntp.org 1.north-america.pool.ntp.org", ntpConfig.Content)
	assert.Equal(t, fakesys.FakeFileTypeFile, ntpConfig.FileType)

	assert.Equal(t, 1, len(deps.cmdRunner.RunCommands))
	assert.Equal(t, []string{"ntpdate"}, deps.cmdRunner.RunCommands[0])
}

func TestUbuntuSetTimeWithNtpServersIsNoopWhenNoNtpServerProvided(t *testing.T) {
	deps, ubuntu := buildUbuntu(1*time.Millisecond, 1*time.Millisecond)

	ubuntu.SetTimeWithNtpServers([]string{})
	assert.Equal(t, 0, len(deps.cmdRunner.RunCommands))

	ntpConfig := deps.fs.GetFileTestStat("/fake-dir/bosh/etc/ntpserver")
	assert.Nil(t, ntpConfig)
}

func TestUbuntuSetupEphemeralDiskWithPath(t *testing.T) {
	deps, ubuntu := buildUbuntu(1*time.Millisecond, 1*time.Millisecond)
	fakeFormatter := deps.diskManager.FakeFormatter
	fakePartitioner := deps.diskManager.FakePartitioner
	fakeMounter := deps.diskManager.FakeMounter

	fakePartitioner.GetDeviceSizeInMbSizes = map[string]uint64{"/dev/xvda": uint64(1024 * 1024 * 1024)}

	deps.fs.WriteToFile("/dev/xvda", "")

	err := ubuntu.SetupEphemeralDiskWithPath("/dev/xvda")
	assert.NoError(t, err)

	dataDir := deps.fs.GetFileTestStat("/fake-dir/data")
	assert.Equal(t, fakesys.FakeFileTypeDir, dataDir.FileType)
	assert.Equal(t, os.FileMode(0750), dataDir.FileMode)

	assert.Equal(t, "/dev/xvda", fakePartitioner.PartitionDevicePath)
	assert.Equal(t, 2, len(fakePartitioner.PartitionPartitions))

	swapPartition := fakePartitioner.PartitionPartitions[0]
	ext4Partition := fakePartitioner.PartitionPartitions[1]

	assert.Equal(t, "swap", swapPartition.Type)
	assert.Equal(t, "linux", ext4Partition.Type)

	assert.Equal(t, 2, len(fakeFormatter.FormatPartitionPaths))
	assert.Equal(t, "/dev/xvda1", fakeFormatter.FormatPartitionPaths[0])
	assert.Equal(t, "/dev/xvda2", fakeFormatter.FormatPartitionPaths[1])

	assert.Equal(t, 2, len(fakeFormatter.FormatFsTypes))
	assert.Equal(t, boshdisk.FileSystemSwap, fakeFormatter.FormatFsTypes[0])
	assert.Equal(t, boshdisk.FileSystemExt4, fakeFormatter.FormatFsTypes[1])

	assert.Equal(t, 1, len(fakeMounter.MountMountPoints))
	assert.Equal(t, "/fake-dir/data", fakeMounter.MountMountPoints[0])
	assert.Equal(t, 1, len(fakeMounter.MountPartitionPaths))
	assert.Equal(t, "/dev/xvda2", fakeMounter.MountPartitionPaths[0])

	assert.Equal(t, 1, len(fakeMounter.SwapOnPartitionPaths))
	assert.Equal(t, "/dev/xvda1", fakeMounter.SwapOnPartitionPaths[0])

	sysLogStats := deps.fs.GetFileTestStat("/fake-dir/data/sys/log")
	assert.NotNil(t, sysLogStats)
	assert.Equal(t, fakesys.FakeFileTypeDir, sysLogStats.FileType)
	assert.Equal(t, os.FileMode(0750), sysLogStats.FileMode)
	assert.Equal(t, []string{"chown", "root:vcap", "/fake-dir/data/sys"}, deps.cmdRunner.RunCommands[0])
	assert.Equal(t, []string{"chown", "root:vcap", "/fake-dir/data/sys/log"}, deps.cmdRunner.RunCommands[1])

	sysRunStats := deps.fs.GetFileTestStat("/fake-dir/data/sys/run")
	assert.NotNil(t, sysRunStats)
	assert.Equal(t, fakesys.FakeFileTypeDir, sysRunStats.FileType)
	assert.Equal(t, os.FileMode(0750), sysRunStats.FileMode)
	assert.Equal(t, []string{"chown", "root:vcap", "/fake-dir/data/sys/run"}, deps.cmdRunner.RunCommands[2])
}

func TestSetupTmpDir(t *testing.T) {
	deps, ubuntu := buildUbuntu(1*time.Millisecond, 1*time.Millisecond)

	err := ubuntu.SetupTmpDir()
	assert.NoError(t, err)

	assert.Equal(t, 2, len(deps.cmdRunner.RunCommands))

	assert.Equal(t, []string{"chown", "root:vcap", "/tmp"}, deps.cmdRunner.RunCommands[0])
	assert.Equal(t, []string{"chmod", "0770", "/tmp"}, deps.cmdRunner.RunCommands[1])
}

func TestUbuntuMountPersistentDisk(t *testing.T) {
	deps, ubuntu := buildUbuntu(1*time.Millisecond, 1*time.Millisecond)
	fakeFormatter := deps.diskManager.FakeFormatter
	fakePartitioner := deps.diskManager.FakePartitioner
	fakeMounter := deps.diskManager.FakeMounter

	deps.fs.WriteToFile("/dev/vdf", "")

	err := ubuntu.MountPersistentDisk("/dev/sdf", "/mnt/point")
	assert.NoError(t, err)

	mountPoint := deps.fs.GetFileTestStat("/mnt/point")
	assert.Equal(t, fakesys.FakeFileTypeDir, mountPoint.FileType)
	assert.Equal(t, os.FileMode(0700), mountPoint.FileMode)

	partition := fakePartitioner.PartitionPartitions[0]
	assert.Equal(t, "/dev/vdf", fakePartitioner.PartitionDevicePath)
	assert.Equal(t, 1, len(fakePartitioner.PartitionPartitions))
	assert.Equal(t, "linux", partition.Type)

	assert.Equal(t, 1, len(fakeFormatter.FormatPartitionPaths))
	assert.Equal(t, "/dev/vdf1", fakeFormatter.FormatPartitionPaths[0])

	assert.Equal(t, 1, len(fakeFormatter.FormatFsTypes))
	assert.Equal(t, boshdisk.FileSystemExt4, fakeFormatter.FormatFsTypes[0])

	assert.Equal(t, 1, len(fakeMounter.MountMountPoints))
	assert.Equal(t, "/mnt/point", fakeMounter.MountMountPoints[0])
	assert.Equal(t, 1, len(fakeMounter.MountPartitionPaths))
	assert.Equal(t, "/dev/vdf1", fakeMounter.MountPartitionPaths[0])
}

func TestUbuntuUnmountPersistentDiskWhenNotMounted(t *testing.T) {
	testUbuntuUnmountPersistentDisk(t, false)
}

func TestUbuntuUnmountPersistentDiskWhenAlreadyMounted(t *testing.T) {
	testUbuntuUnmountPersistentDisk(t, true)
}

func testUbuntuUnmountPersistentDisk(t *testing.T, isMounted bool) {
	deps, ubuntu := buildUbuntu(1*time.Millisecond, 1*time.Millisecond)
	fakeMounter := deps.diskManager.FakeMounter
	fakeMounter.UnmountDidUnmount = !isMounted

	deps.fs.WriteToFile("/dev/vdx", "")

	didUnmount, err := ubuntu.UnmountPersistentDisk("/dev/sdx")
	assert.NoError(t, err)
	assert.Equal(t, didUnmount, !isMounted)
	assert.Equal(t, "/dev/vdx1", fakeMounter.UnmountPartitionPath)
}

func TestUbuntuNormalizeDiskPath(t *testing.T) {
	deps, ubuntu := buildUbuntu(1*time.Millisecond, 1*time.Millisecond)

	deps.fs.WriteToFile("/dev/xvda", "")
	path, found := ubuntu.NormalizeDiskPath("/dev/sda")

	assert.Equal(t, path, "/dev/xvda")
	assert.True(t, found)

	deps.fs.RemoveAll("/dev/xvda")
	deps.fs.WriteToFile("/dev/vda", "")
	path, found = ubuntu.NormalizeDiskPath("/dev/sda")

	assert.Equal(t, path, "/dev/vda")
	assert.True(t, found)

	deps.fs.RemoveAll("/dev/vda")
	deps.fs.WriteToFile("/dev/sda", "")
	path, found = ubuntu.NormalizeDiskPath("/dev/sda")

	assert.Equal(t, path, "/dev/sda")
	assert.True(t, found)
}

func TestUbuntuGetFileContentsFromCDROM(t *testing.T) {
	deps, ubuntu := buildUbuntu(1*time.Millisecond, 1*time.Millisecond)

	deps.fs.WriteToFile("/dev/bosh-cdrom", "")
	settingsPath := filepath.Join(ubuntu.GetDirProvider().SettingsDir(), "env")
	deps.fs.WriteToFile(settingsPath, "some stuff")
	deps.fs.WriteToFile("/proc/sys/dev/cdrom/info", "CD-ROM information, Id: cdrom.c 3.20 2003/12/17\n\ndrive name:		sr0\ndrive speed:		32\n")

	contents, err := ubuntu.GetFileContentsFromCDROM("env")
	assert.NoError(t, err)

	assert.Equal(t, 3, len(deps.cmdRunner.RunCommands))
	assert.Equal(t, []string{"mount", "/dev/sr0", "/fake-dir/bosh/settings"}, deps.cmdRunner.RunCommands[0])
	assert.Equal(t, []string{"umount", "/fake-dir/bosh/settings"}, deps.cmdRunner.RunCommands[1])
	assert.Equal(t, []string{"eject", "/dev/sr0"}, deps.cmdRunner.RunCommands[2])

	assert.Equal(t, contents, []byte("some stuff"))
}

func TestUbuntuGetFileContentsFromCDROMWhenCDROMFailedToLoad(t *testing.T) {
	deps, ubuntu := buildUbuntu(1*time.Millisecond, 1*time.Millisecond)

	deps.fs.WriteToFile("/dev/sr0/env", "some stuff")
	deps.fs.WriteToFile("/proc/sys/dev/cdrom/info", "CD-ROM information, Id: cdrom.c 3.20 2003/12/17\n\ndrive name:		sr0\ndrive speed:		32\n")

	_, err := ubuntu.GetFileContentsFromCDROM("env")
	assert.Error(t, err)
}

func TestUbuntuGetFileContentsFromCDROMRetriesCDROMReading(t *testing.T) {
	deps, ubuntu := buildUbuntu(1*time.Second, 1*time.Millisecond)

	settingsPath := filepath.Join(ubuntu.GetDirProvider().SettingsDir(), "env")
	deps.fs.WriteToFile(settingsPath, "some stuff")
	deps.fs.WriteToFile("/proc/sys/dev/cdrom/info", "CD-ROM information, Id: cdrom.c 3.20 2003/12/17\n\ndrive name:		sr0\ndrive speed:		32\n")

	go func() {
		_, err := ubuntu.GetFileContentsFromCDROM("env")
		assert.NoError(t, err)
	}()

	time.Sleep(500 * time.Millisecond)
	deps.fs.WriteToFile("/dev/bosh-cdrom", "")
}

func TestUbuntuGetRealDevicePathWithMultiplePossibleDevices(t *testing.T) {
	deps, ubuntu := buildUbuntu(1*time.Millisecond, 1*time.Millisecond)

	deps.fs.WriteToFile("/dev/xvda", "")
	deps.fs.WriteToFile("/dev/vda", "")

	realPath, found := ubuntu.NormalizeDiskPath("/dev/sda")
	assert.True(t, found)
	assert.Equal(t, "/dev/xvda", realPath)
}

func TestUbuntuGetRealDevicePathWithDelayWithinTimeout(t *testing.T) {
	deps, ubuntu := buildUbuntu(1*time.Millisecond, 1*time.Second)

	time.AfterFunc(time.Second, func() {
		deps.fs.WriteToFile("/dev/xvda", "")
	})

	realPath, found := ubuntu.NormalizeDiskPath("/dev/sda")
	assert.True(t, found)
	assert.Equal(t, "/dev/xvda", realPath)
}

func TestUbuntuGetRealDevicePathWithDelayBeyondTimeout(t *testing.T) {
	deps, ubuntu := buildUbuntu(1*time.Millisecond, 1*time.Millisecond)

	time.AfterFunc(2*time.Second, func() {
		deps.fs.WriteToFile("/dev/xvda", "")
	})

	_, found := ubuntu.NormalizeDiskPath("/dev/sda")
	assert.False(t, found)
}

func TestUbuntuCalculateEphemeralDiskPartitionSizesWhenDiskIsBiggerThanTwiceTheMemory(t *testing.T) {
	totalMemInMb := uint64(1024)

	diskSizeInMb := totalMemInMb*2 + 64
	expectedSwap := totalMemInMb
	testUbuntuCalculateEphemeralDiskPartitionSizes(t, totalMemInMb, diskSizeInMb, expectedSwap)
}

func TestUbuntuCalculateEphemeralDiskPartitionSizesWhenDiskTwiceTheMemoryOrSmaller(t *testing.T) {
	totalMemInMb := uint64(1024)

	diskSizeInMb := totalMemInMb*2 - 64
	expectedSwap := diskSizeInMb / 2
	testUbuntuCalculateEphemeralDiskPartitionSizes(t, totalMemInMb, diskSizeInMb, expectedSwap)
}

func testUbuntuCalculateEphemeralDiskPartitionSizes(t *testing.T, totalMemInMb, diskSizeInMb, expectedSwap uint64) {
	deps, ubuntu := buildUbuntu(1*time.Millisecond, 1*time.Millisecond)
	deps.collector.MemStats.Total = totalMemInMb * uint64(1024*1024)

	fakePartitioner := deps.diskManager.FakePartitioner
	fakePartitioner.GetDeviceSizeInMbSizes = map[string]uint64{
		"/dev/hda": diskSizeInMb,
	}

	err := ubuntu.SetupEphemeralDiskWithPath("/dev/hda")

	assert.NoError(t, err)
	expectedPartitions := []boshdisk.Partition{
		{SizeInMb: expectedSwap, Type: boshdisk.PartitionTypeSwap},
		{SizeInMb: diskSizeInMb - expectedSwap, Type: boshdisk.PartitionTypeLinux},
	}
	assert.Equal(t, fakePartitioner.PartitionPartitions, expectedPartitions)
}

func TestUbuntuMigratePersistentDisk(t *testing.T) {
	deps, ubuntu := buildUbuntu(1*time.Millisecond, 1*time.Millisecond)
	fakeMounter := deps.diskManager.FakeMounter

	ubuntu.MigratePersistentDisk("/from/path", "/to/path")

	assert.Equal(t, fakeMounter.RemountAsReadonlyPath, "/from/path")

	assert.Equal(t, 1, len(deps.cmdRunner.RunCommands))
	assert.Equal(t, []string{"sh", "-c", "(tar -C /from/path -cf - .) | (tar -C /to/path -xpf -)"}, deps.cmdRunner.RunCommands[0])

	assert.Equal(t, fakeMounter.UnmountPartitionPath, "/from/path")
	assert.Equal(t, fakeMounter.RemountFromMountPoint, "/to/path")
	assert.Equal(t, fakeMounter.RemountToMountPoint, "/from/path")
}

func TestUbuntuIsDevicePathMounted(t *testing.T) {
	deps, ubuntu := buildUbuntu(1*time.Millisecond, 1*time.Millisecond)

	deps.fs.WriteToFile("/dev/xvda", "")
	fakeMounter := deps.diskManager.FakeMounter
	fakeMounter.IsMountedResult = true

	result, err := ubuntu.IsDevicePathMounted("/dev/sda")
	assert.NoError(t, err)
	assert.True(t, result)
	assert.Equal(t, fakeMounter.IsMountedDevicePathOrMountPoint, "/dev/xvda1")
}

func TestUbuntuStartMonit(t *testing.T) {
	deps, ubuntu := buildUbuntu(1*time.Millisecond, 1*time.Millisecond)

	err := ubuntu.StartMonit()
	assert.NoError(t, err)
	assert.Equal(t, 1, len(deps.cmdRunner.RunCommands))
	assert.Equal(t, []string{"sv", "up", "monit"}, deps.cmdRunner.RunCommands[0])
}

func TestUbuntuSetupMonitUserIfFileDoesNotExist(t *testing.T) {
	deps, ubuntu := buildUbuntu(1*time.Millisecond, 1*time.Millisecond)

	err := ubuntu.SetupMonitUser()
	assert.NoError(t, err)

	monitUserFileStats := deps.fs.GetFileTestStat("/fake-dir/monit/monit.user")
	assert.NotNil(t, monitUserFileStats)
	assert.Equal(t, "vcap:random-password", monitUserFileStats.Content)
}

func TestUbuntuSetupMonitUserIfFileDoesExist(t *testing.T) {
	deps, ubuntu := buildUbuntu(1*time.Millisecond, 1*time.Millisecond)

	deps.fs.WriteToFile("/fake-dir/monit/monit.user", "vcap:other-random-password")

	err := ubuntu.SetupMonitUser()
	assert.NoError(t, err)

	monitUserFileStats := deps.fs.GetFileTestStat("/fake-dir/monit/monit.user")
	assert.NotNil(t, monitUserFileStats)
	assert.Equal(t, "vcap:other-random-password", monitUserFileStats.Content)
}

func TestUbuntuGetMonitCredentialsReadsMonitFileFromDisk(t *testing.T) {
	deps, ubuntu := buildUbuntu(1*time.Millisecond, 1*time.Millisecond)

	deps.fs.WriteToFile("/fake-dir/monit/monit.user", "fake-user:fake-random-password")

	username, password, err := ubuntu.GetMonitCredentials()
	assert.NoError(t, err)

	assert.Equal(t, "fake-user", username)
	assert.Equal(t, "fake-random-password", password)
}

func TestUbuntuGetMonitCredentialsErrsWhenInvalidFileFormat(t *testing.T) {
	deps, ubuntu := buildUbuntu(1*time.Millisecond, 1*time.Millisecond)

	deps.fs.WriteToFile("/fake-dir/monit/monit.user", "fake-user")

	_, _, err := ubuntu.GetMonitCredentials()
	assert.Error(t, err)
}

func TestUbuntuGetMonitCredentialsLeavesColonsInPasswordIntact(t *testing.T) {
	deps, ubuntu := buildUbuntu(1*time.Millisecond, 1*time.Millisecond)
	deps.fs.WriteToFile("/fake-dir/monit/monit.user", "fake-user:fake:random:password")

	username, password, err := ubuntu.GetMonitCredentials()
	assert.NoError(t, err)

	assert.Equal(t, "fake-user", username)
	assert.Equal(t, "fake:random:password", password)
}

type ubuntuDependencies struct {
	collector   *fakestats.FakeStatsCollector
	fs          *fakesys.FakeFileSystem
	cmdRunner   *fakesys.FakeCmdRunner
	diskManager fakedisk.FakeDiskManager
	dirProvider boshdirs.DirectoriesProvider
}

func buildUbuntu(cdromWaitInterval time.Duration, diskWaitTimeout time.Duration) (
	deps ubuntuDependencies,
	platform Platform,
) {
	deps.collector = &fakestats.FakeStatsCollector{}
	deps.fs = &fakesys.FakeFileSystem{}
	deps.cmdRunner = &fakesys.FakeCmdRunner{}
	deps.diskManager = fakedisk.NewFakeDiskManager(deps.cmdRunner)
	deps.dirProvider = boshdirs.NewDirectoriesProvider("/fake-dir")

	platform = NewUbuntuPlatform(
		deps.collector,
		deps.fs,
		deps.cmdRunner,
		deps.diskManager,
		deps.dirProvider,
		cdromWaitInterval,
		1*time.Millisecond,
		diskWaitTimeout,
	)
	return
}
