package platform

import (
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

func TestSetupRuntimeConfiguration(t *testing.T) {
	deps, ubuntu := buildUbuntu()

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
	deps, ubuntu := buildUbuntu()

	err := ubuntu.CreateUser("foo-user", password, "/some/path/to/home")
	assert.NoError(t, err)

	basePathStat := deps.fs.GetFileTestStat("/some/path/to/home")
	assert.Equal(t, fakesys.FakeFileTypeDir, basePathStat.FileType)
	assert.Equal(t, os.FileMode(0755), basePathStat.FileMode)

	assert.Equal(t, 1, len(deps.cmdRunner.RunCommands))
	assert.Equal(t, expectedUseradd, deps.cmdRunner.RunCommands[0])
}

func TestAddUserToGroups(t *testing.T) {
	deps, ubuntu := buildUbuntu()

	err := ubuntu.AddUserToGroups("foo-user", []string{"group1", "group2", "group3"})
	assert.NoError(t, err)

	assert.Equal(t, 1, len(deps.cmdRunner.RunCommands))

	usermod := []string{"usermod", "-G", "group1,group2,group3", "foo-user"}
	assert.Equal(t, usermod, deps.cmdRunner.RunCommands[0])
}

func TestDeleteUsersWithPrefixAndRegex(t *testing.T) {
	deps, ubuntu := buildUbuntu()

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
	deps, ubuntu := buildUbuntu()
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
	deps, ubuntu := buildUbuntu()

	ubuntu.SetUserPassword("my-user", "my-encrypted-password")
	assert.Equal(t, 1, len(deps.cmdRunner.RunCommands))
	assert.Equal(t, []string{"usermod", "-p", "my-encrypted-password", "my-user"}, deps.cmdRunner.RunCommands[0])
}

func TestUbuntuSetupHostname(t *testing.T) {
	deps, ubuntu := buildUbuntu()

	ubuntu.SetupHostname("foobar.local")
	assert.Equal(t, 1, len(deps.cmdRunner.RunCommands))
	assert.Equal(t, []string{"hostname", "foobar.local"}, deps.cmdRunner.RunCommands[0])

	hostnameFileContent, err := deps.fs.ReadFile("/etc/hostname")
	assert.NoError(t, err)
	assert.Equal(t, "foobar.local", hostnameFileContent)

	hostsFileContent, err := deps.fs.ReadFile("/etc/hosts")
	assert.NoError(t, err)
	assert.Equal(t, EXPECTED_ETC_HOSTS, hostsFileContent)
}

const EXPECTED_ETC_HOSTS = `127.0.0.1 localhost foobar.local

# The following lines are desirable for IPv6 capable hosts
::1 localhost ip6-localhost ip6-loopback foobar.local
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
ff02::3 ip6-allhosts
`

func TestUbuntuSetupDhcp(t *testing.T) {
	deps, ubuntu := buildUbuntu()
	testUbuntuSetupDhcp(t, deps, ubuntu)

	assert.Equal(t, len(deps.cmdRunner.RunCommands), 2)
	assert.Equal(t, deps.cmdRunner.RunCommands[0], []string{"pkill", "dhclient3"})
	assert.Equal(t, deps.cmdRunner.RunCommands[1], []string{"/etc/init.d/networking", "restart"})
}

func TestUbuntuSetupDhcpWithPreExistingConfiguration(t *testing.T) {
	deps, ubuntu := buildUbuntu()
	deps.fs.WriteToFile("/etc/dhcp3/dhclient.conf", EXPECTED_DHCP_CONFIG)
	testUbuntuSetupDhcp(t, deps, ubuntu)

	assert.Equal(t, len(deps.cmdRunner.RunCommands), 0)
}

func testUbuntuSetupDhcp(
	t *testing.T,
	deps ubuntuDependencies,
	platform ubuntu,
) {
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
	assert.Equal(t, dhcpConfig.Content, EXPECTED_DHCP_CONFIG)
}

const EXPECTED_DHCP_CONFIG = `# Generated by bosh-agent

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

func TestUbuntuSetupLogrotate(t *testing.T) {
	deps, ubuntu := buildUbuntu()

	ubuntu.SetupLogrotate("fake-group-name", "fake-base-path", "fake-size")

	logrotateFileContent, err := deps.fs.ReadFile("/etc/logrotate.d/fake-group-name")
	assert.NoError(t, err)
	assert.Equal(t, EXPECTED_ETC_LOGROTATE, logrotateFileContent)
}

const EXPECTED_ETC_LOGROTATE = `# Generated by bosh-agent

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
	deps, ubuntu := buildUbuntu()

	ubuntu.SetTimeWithNtpServers([]string{"0.north-america.pool.ntp.org", "1.north-america.pool.ntp.org"})
	assert.Equal(t, 1, len(deps.cmdRunner.RunCommands))
	assert.Equal(t, []string{"ntpdate", "0.north-america.pool.ntp.org", "1.north-america.pool.ntp.org"}, deps.cmdRunner.RunCommands[0])

	ntpConfig := deps.fs.GetFileTestStat("/fake-dir/bosh/etc/ntpserver")
	assert.Equal(t, "0.north-america.pool.ntp.org 1.north-america.pool.ntp.org", ntpConfig.Content)
	assert.Equal(t, fakesys.FakeFileTypeFile, ntpConfig.FileType)
}

func TestUbuntuSetTimeWithNtpServersIsNoopWhenNoNtpServerProvided(t *testing.T) {
	deps, ubuntu := buildUbuntu()

	ubuntu.SetTimeWithNtpServers([]string{})
	assert.Equal(t, 0, len(deps.cmdRunner.RunCommands))

	ntpConfig := deps.fs.GetFileTestStat("/fake-dir/bosh/etc/ntpserver")
	assert.Nil(t, ntpConfig)
}

func TestUbuntuSetupEphemeralDiskWithPath(t *testing.T) {
	deps, ubuntu := buildUbuntu()
	fakeFormatter := deps.diskManager.FakeFormatter
	fakePartitioner := deps.diskManager.FakePartitioner
	fakeMounter := deps.diskManager.FakeMounter

	fakePartitioner.GetDeviceSizeInMbSizes = map[string]uint64{"/dev/xvda": uint64(1024 * 1024 * 1024)}

	deps.fs.WriteToFile("/dev/xvda", "")

	err := ubuntu.SetupEphemeralDiskWithPath("/dev/sda")
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

	sysRunStats := deps.fs.GetFileTestStat("/fake-dir/data/sys/run")
	assert.NotNil(t, sysRunStats)
	assert.Equal(t, fakesys.FakeFileTypeDir, sysRunStats.FileType)
	assert.Equal(t, os.FileMode(0750), sysRunStats.FileMode)
}

func TestUbuntuMountPersistentDisk(t *testing.T) {
	deps, ubuntu := buildUbuntu()
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
	deps, ubuntu := buildUbuntu()
	fakeMounter := deps.diskManager.FakeMounter
	fakeMounter.UnmountDidUnmount = !isMounted

	deps.fs.WriteToFile("/dev/vdx", "")

	didUnmount, err := ubuntu.UnmountPersistentDisk("/dev/sdx")
	assert.NoError(t, err)
	assert.Equal(t, didUnmount, !isMounted)
	assert.Equal(t, "/dev/vdx1", fakeMounter.UnmountPartitionPath)
}

func TestUbuntuGetRealDevicePathWithMultiplePossibleDevices(t *testing.T) {
	deps, ubuntu := buildUbuntu()

	deps.fs.WriteToFile("/dev/xvda", "")
	deps.fs.WriteToFile("/dev/vda", "")

	realPath, err := ubuntu.getRealDevicePath("/dev/sda")
	assert.NoError(t, err)
	assert.Equal(t, "/dev/xvda", realPath)
}

func TestUbuntuGetRealDevicePathWithDelayWithinTimeout(t *testing.T) {
	deps, ubuntu := buildUbuntu()

	time.AfterFunc(time.Second, func() {
		deps.fs.WriteToFile("/dev/xvda", "")
	})

	realPath, err := ubuntu.getRealDevicePath("/dev/sda")
	assert.NoError(t, err)
	assert.Equal(t, "/dev/xvda", realPath)
}

func TestUbuntuGetRealDevicePathWithDelayBeyondTimeout(t *testing.T) {
	deps, ubuntu := buildUbuntu()

	ubuntu.diskWaitTimeout = time.Second

	time.AfterFunc(2*time.Second, func() {
		deps.fs.WriteToFile("/dev/xvda", "")
	})

	_, err := ubuntu.getRealDevicePath("/dev/sda")
	assert.Error(t, err)
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
	deps, ubuntu := buildUbuntu()
	deps.collector.MemStats.Total = totalMemInMb * uint64(1024*1024)

	fakePartitioner := deps.diskManager.FakePartitioner
	fakePartitioner.GetDeviceSizeInMbSizes = map[string]uint64{
		"/dev/hda": diskSizeInMb,
	}

	swapSize, linuxSize, err := ubuntu.calculateEphemeralDiskPartitionSizes("/dev/hda")

	assert.NoError(t, err)
	assert.Equal(t, expectedSwap, swapSize)
	assert.Equal(t, diskSizeInMb-expectedSwap, linuxSize)
}

func TestUbuntuMigratePersistentDisk(t *testing.T) {
	deps, ubuntu := buildUbuntu()
	fakeMounter := deps.diskManager.FakeMounter

	ubuntu.MigratePersistentDisk("/from/path", "/to/path")

	assert.Equal(t, fakeMounter.RemountAsReadonlyPath, "/from/path")

	assert.Equal(t, 1, len(deps.cmdRunner.RunCommands))
	assert.Equal(t, []string{"sh", "-c", "(tar -C /from/path -cf - .) | (tar -C /to/path -xpf -)"}, deps.cmdRunner.RunCommands[0])

	assert.Equal(t, fakeMounter.UnmountPartitionPath, "/from/path")
	assert.Equal(t, fakeMounter.RemountFromMountPoint, "/to/path")
	assert.Equal(t, fakeMounter.RemountToMountPoint, "/from/path")
}

func TestIsDevicePathMounted(t *testing.T) {
	deps, ubuntu := buildUbuntu()

	deps.fs.WriteToFile("/dev/xvda", "")
	fakeMounter := deps.diskManager.FakeMounter
	fakeMounter.IsMountedResult = true

	result, err := ubuntu.IsDevicePathMounted("/dev/sda")
	assert.NoError(t, err)
	assert.True(t, result)
	assert.Equal(t, fakeMounter.IsMountedDevicePathOrMountPoint, "/dev/xvda1")
}

func TestStartMonit(t *testing.T) {
	deps, ubuntu := buildUbuntu()

	err := ubuntu.StartMonit()
	assert.NoError(t, err)
	assert.Equal(t, 1, len(deps.cmdRunner.RunCommands))
	assert.Equal(t, []string{"sv", "up", "monit"}, deps.cmdRunner.RunCommands[0])
}

func TestSetupMonitUserIfFileDoesNotExist(t *testing.T) {
	deps, ubuntu := buildUbuntu()

	err := ubuntu.SetupMonitUser()
	assert.NoError(t, err)

	monitUserFileStats := deps.fs.GetFileTestStat("/fake-dir/monit/monit.user")
	assert.NotNil(t, monitUserFileStats)
	assert.Equal(t, "vcap:random-password", monitUserFileStats.Content)
}

func TestSetupMonitUserIfFileDoesExist(t *testing.T) {
	deps, ubuntu := buildUbuntu()

	deps.fs.WriteToFile("/fake-dir/monit/monit.user", "vcap:other-random-password")

	err := ubuntu.SetupMonitUser()
	assert.NoError(t, err)

	monitUserFileStats := deps.fs.GetFileTestStat("/fake-dir/monit/monit.user")
	assert.NotNil(t, monitUserFileStats)
	assert.Equal(t, "vcap:other-random-password", monitUserFileStats.Content)
}

func TestGetMonitCredentialsReadsMonitFileFromDisk(t *testing.T) {
	deps, ubuntu := buildUbuntu()

	deps.fs.WriteToFile("/fake-dir/monit/monit.user", "fake-user:fake-random-password")

	username, password, err := ubuntu.GetMonitCredentials()
	assert.NoError(t, err)

	assert.Equal(t, "fake-user", username)
	assert.Equal(t, "fake-random-password", password)
}

func TestGetMonitCredentialsErrsWhenInvalidFileFormat(t *testing.T) {
	deps, ubuntu := buildUbuntu()

	deps.fs.WriteToFile("/fake-dir/monit/monit.user", "fake-user")

	_, _, err := ubuntu.GetMonitCredentials()
	assert.Error(t, err)
}

func TestGetMonitCredentialsLeavesColonsInPasswordIntact(t *testing.T) {
	deps, ubuntu := buildUbuntu()
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

func buildUbuntu() (
	deps ubuntuDependencies,
	platform ubuntu,
) {
	deps.collector = &fakestats.FakeStatsCollector{}
	deps.fs = &fakesys.FakeFileSystem{}
	deps.cmdRunner = &fakesys.FakeCmdRunner{}
	deps.diskManager = fakedisk.NewFakeDiskManager(deps.cmdRunner)
	deps.dirProvider = boshdirs.NewDirectoriesProvider("/fake-dir")

	platform = newUbuntuPlatform(
		deps.collector,
		deps.fs,
		deps.cmdRunner,
		deps.diskManager,
		deps.dirProvider,
	)
	return
}
