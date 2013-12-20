package platform

import (
	fakecmd "bosh/platform/commands/fakes"
	boshdisk "bosh/platform/disk"
	fakedisk "bosh/platform/disk/fakes"
	fakestats "bosh/platform/stats/fakes"
	boshsettings "bosh/settings"
	fakesys "bosh/system/fakes"
	"fmt"
	"github.com/stretchr/testify/assert"
	"os"
	"path/filepath"
	"testing"
	"time"
)

func TestSetupRuntimeConfiguration(t *testing.T) {
	fakeStats, fakeFs, fakeCmdRunner, fakeDiskManager, fakeCompressor := getUbuntuDependencies()
	ubuntu := newUbuntuPlatform(fakeStats, fakeFs, fakeCmdRunner, fakeDiskManager, fakeCompressor)

	err := ubuntu.SetupRuntimeConfiguration()
	assert.NoError(t, err)

	assert.Equal(t, 1, len(fakeCmdRunner.RunCommands))
	assert.Equal(t, []string{"bosh-agent-rc"}, fakeCmdRunner.RunCommands[0])
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
	fakeStats, fakeFs, fakeCmdRunner, fakeDiskManager, fakeCompressor := getUbuntuDependencies()
	ubuntu := newUbuntuPlatform(fakeStats, fakeFs, fakeCmdRunner, fakeDiskManager, fakeCompressor)

	err := ubuntu.CreateUser("foo-user", password, "/some/path/to/home")
	assert.NoError(t, err)

	basePathStat := fakeFs.GetFileTestStat("/some/path/to/home")
	assert.Equal(t, fakesys.FakeFileTypeDir, basePathStat.FileType)
	assert.Equal(t, os.FileMode(0755), basePathStat.FileMode)

	assert.Equal(t, 1, len(fakeCmdRunner.RunCommands))
	assert.Equal(t, expectedUseradd, fakeCmdRunner.RunCommands[0])
}

func TestAddUserToGroups(t *testing.T) {
	fakeStats, fakeFs, fakeCmdRunner, fakeDiskManager, fakeCompressor := getUbuntuDependencies()
	ubuntu := newUbuntuPlatform(fakeStats, fakeFs, fakeCmdRunner, fakeDiskManager, fakeCompressor)

	err := ubuntu.AddUserToGroups("foo-user", []string{"group1", "group2", "group3"})
	assert.NoError(t, err)

	assert.Equal(t, 1, len(fakeCmdRunner.RunCommands))

	usermod := []string{"usermod", "-G", "group1,group2,group3", "foo-user"}
	assert.Equal(t, usermod, fakeCmdRunner.RunCommands[0])
}

func TestDeleteUsersWithPrefixAndRegex(t *testing.T) {
	fakeStats, fakeFs, fakeCmdRunner, fakeDiskManager, fakeCompressor := getUbuntuDependencies()

	passwdFile := fmt.Sprintf(`%sfoo:...
%sbar:...
foo:...
bar:...
foobar:...
%sfoobar:...`,
		boshsettings.EPHEMERAL_USER_PREFIX, boshsettings.EPHEMERAL_USER_PREFIX, boshsettings.EPHEMERAL_USER_PREFIX,
	)

	fakeFs.WriteToFile("/etc/passwd", passwdFile)

	ubuntu := newUbuntuPlatform(fakeStats, fakeFs, fakeCmdRunner, fakeDiskManager, fakeCompressor)

	err := ubuntu.DeleteEphemeralUsersMatching("bar$")
	assert.NoError(t, err)
	assert.Equal(t, 2, len(fakeCmdRunner.RunCommands))
	assert.Equal(t, []string{"userdel", "-r", "bosh_bar"}, fakeCmdRunner.RunCommands[0])
	assert.Equal(t, []string{"userdel", "-r", "bosh_foobar"}, fakeCmdRunner.RunCommands[1])
}

func TestUbuntuSetupSsh(t *testing.T) {
	fakeStats, fakeFs, fakeCmdRunner, fakeDiskManager, fakeCompressor := getUbuntuDependencies()
	fakeFs.HomeDirHomePath = "/some/home/dir"

	ubuntu := newUbuntuPlatform(fakeStats, fakeFs, fakeCmdRunner, fakeDiskManager, fakeCompressor)
	ubuntu.SetupSsh("some public key", "vcap")

	sshDirPath := "/some/home/dir/.ssh"
	sshDirStat := fakeFs.GetFileTestStat(sshDirPath)

	assert.Equal(t, fakeFs.HomeDirUsername, "vcap")

	assert.NotNil(t, sshDirStat)
	assert.Equal(t, fakesys.FakeFileTypeDir, sshDirStat.FileType)
	assert.Equal(t, sshDirStat.FileMode, os.FileMode(0700))
	assert.Equal(t, sshDirStat.Username, "vcap")

	authKeysStat := fakeFs.GetFileTestStat(filepath.Join(sshDirPath, "authorized_keys"))

	assert.NotNil(t, authKeysStat)
	assert.Equal(t, authKeysStat.FileType, fakesys.FakeFileTypeFile)
	assert.Equal(t, authKeysStat.FileMode, os.FileMode(0600))
	assert.Equal(t, authKeysStat.Username, "vcap")
	assert.Equal(t, authKeysStat.Content, "some public key")
}

func TestUbuntuSetUserPassword(t *testing.T) {
	fakeStats, fakeFs, fakeCmdRunner, fakeDiskManager, fakeCompressor := getUbuntuDependencies()
	ubuntu := newUbuntuPlatform(fakeStats, fakeFs, fakeCmdRunner, fakeDiskManager, fakeCompressor)

	ubuntu.SetUserPassword("my-user", "my-encrypted-password")
	assert.Equal(t, 1, len(fakeCmdRunner.RunCommands))
	assert.Equal(t, []string{"usermod", "-p", "my-encrypted-password", "my-user"}, fakeCmdRunner.RunCommands[0])
}

func TestUbuntuSetupHostname(t *testing.T) {
	fakeStats, fakeFs, fakeCmdRunner, fakeDiskManager, fakeCompressor := getUbuntuDependencies()
	ubuntu := newUbuntuPlatform(fakeStats, fakeFs, fakeCmdRunner, fakeDiskManager, fakeCompressor)

	ubuntu.SetupHostname("foobar.local")
	assert.Equal(t, 1, len(fakeCmdRunner.RunCommands))
	assert.Equal(t, []string{"hostname", "foobar.local"}, fakeCmdRunner.RunCommands[0])

	hostnameFileContent, err := fakeFs.ReadFile("/etc/hostname")
	assert.NoError(t, err)
	assert.Equal(t, "foobar.local", hostnameFileContent)

	hostsFileContent, err := fakeFs.ReadFile("/etc/hosts")
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
	fakeStats, fakeFs, fakeCmdRunner, fakeDiskManager, fakeCompressor := getUbuntuDependencies()
	testUbuntuSetupDhcp(t, fakeStats, fakeFs, fakeCmdRunner, fakeDiskManager, fakeCompressor)

	assert.Equal(t, len(fakeCmdRunner.RunCommands), 2)
	assert.Equal(t, fakeCmdRunner.RunCommands[0], []string{"pkill", "dhclient3"})
	assert.Equal(t, fakeCmdRunner.RunCommands[1], []string{"/etc/init.d/networking", "restart"})
}

func TestUbuntuSetupDhcpWithPreExistingConfiguration(t *testing.T) {
	fakeStats, fakeFs, fakeCmdRunner, fakeDiskManager, fakeCompressor := getUbuntuDependencies()
	fakeFs.WriteToFile("/etc/dhcp3/dhclient.conf", EXPECTED_DHCP_CONFIG)
	testUbuntuSetupDhcp(t, fakeStats, fakeFs, fakeCmdRunner, fakeDiskManager, fakeCompressor)

	assert.Equal(t, len(fakeCmdRunner.RunCommands), 0)
}

func testUbuntuSetupDhcp(
	t *testing.T,
	fakeStats *fakestats.FakeStatsCollector,
	fakeFs *fakesys.FakeFileSystem,
	fakeCmdRunner *fakesys.FakeCmdRunner,
	fakeDiskManager fakedisk.FakeDiskManager,
	fakeCompressor *fakecmd.FakeCompressor,
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

	ubuntu := newUbuntuPlatform(fakeStats, fakeFs, fakeCmdRunner, fakeDiskManager, fakeCompressor)
	ubuntu.SetupDhcp(networks)

	dhcpConfig := fakeFs.GetFileTestStat("/etc/dhcp3/dhclient.conf")
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
	fakeStats, fakeFs, fakeCmdRunner, fakeDiskManager, fakeCompressor := getUbuntuDependencies()
	ubuntu := newUbuntuPlatform(fakeStats, fakeFs, fakeCmdRunner, fakeDiskManager, fakeCompressor)

	ubuntu.SetupLogrotate("fake-group-name", "fake-base-path", "fake-size")

	logrotateFileContent, err := fakeFs.ReadFile("/etc/logrotate.d/fake-group-name")
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
	fakeStats, fakeFs, fakeCmdRunner, fakeDiskManager, fakeCompressor := getUbuntuDependencies()
	ubuntu := newUbuntuPlatform(fakeStats, fakeFs, fakeCmdRunner, fakeDiskManager, fakeCompressor)

	ubuntu.SetTimeWithNtpServers([]string{"0.north-america.pool.ntp.org", "1.north-america.pool.ntp.org"}, "/var/vcap/bosh/etc/ntpserver")
	assert.Equal(t, 1, len(fakeCmdRunner.RunCommands))
	assert.Equal(t, []string{"ntpdate", "0.north-america.pool.ntp.org", "1.north-america.pool.ntp.org"}, fakeCmdRunner.RunCommands[0])

	ntpConfig := fakeFs.GetFileTestStat("/var/vcap/bosh/etc/ntpserver")
	assert.Equal(t, "0.north-america.pool.ntp.org 1.north-america.pool.ntp.org", ntpConfig.Content)
	assert.Equal(t, fakesys.FakeFileTypeFile, ntpConfig.FileType)
}

func TestUbuntuSetTimeWithNtpServersIsNoopWhenNoNtpServerProvided(t *testing.T) {
	fakeStats, fakeFs, fakeCmdRunner, fakeDiskManager, fakeCompressor := getUbuntuDependencies()
	ubuntu := newUbuntuPlatform(fakeStats, fakeFs, fakeCmdRunner, fakeDiskManager, fakeCompressor)

	ubuntu.SetTimeWithNtpServers([]string{}, "/foo/bar")
	assert.Equal(t, 0, len(fakeCmdRunner.RunCommands))

	ntpConfig := fakeFs.GetFileTestStat("/foo/bar")
	assert.Nil(t, ntpConfig)
}

func TestUbuntuSetupEphemeralDiskWithPath(t *testing.T) {
	fakeStats, fakeFs, fakeCmdRunner, fakeDiskManager, fakeCompressor := getUbuntuDependencies()
	fakeFormatter := fakeDiskManager.FakeFormatter
	fakePartitioner := fakeDiskManager.FakePartitioner
	fakeMounter := fakeDiskManager.FakeMounter

	fakePartitioner.GetDeviceSizeInMbSizes = map[string]uint64{"/dev/xvda": uint64(1024 * 1024 * 1024)}
	ubuntu := newUbuntuPlatform(fakeStats, fakeFs, fakeCmdRunner, fakeDiskManager, fakeCompressor)

	fakeFs.WriteToFile("/dev/xvda", "")

	err := ubuntu.SetupEphemeralDiskWithPath("/dev/sda", "/data-dir")
	assert.NoError(t, err)

	dataDir := fakeFs.GetFileTestStat("/data-dir")
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
	assert.Equal(t, "/data-dir", fakeMounter.MountMountPoints[0])
	assert.Equal(t, 1, len(fakeMounter.MountPartitionPaths))
	assert.Equal(t, "/dev/xvda2", fakeMounter.MountPartitionPaths[0])

	assert.Equal(t, 1, len(fakeMounter.SwapOnPartitionPaths))
	assert.Equal(t, "/dev/xvda1", fakeMounter.SwapOnPartitionPaths[0])

	sysLogStats := fakeFs.GetFileTestStat("/data-dir/sys/log")
	assert.NotNil(t, sysLogStats)
	assert.Equal(t, fakesys.FakeFileTypeDir, sysLogStats.FileType)
	assert.Equal(t, os.FileMode(0750), sysLogStats.FileMode)

	sysRunStats := fakeFs.GetFileTestStat("/data-dir/sys/run")
	assert.NotNil(t, sysRunStats)
	assert.Equal(t, fakesys.FakeFileTypeDir, sysRunStats.FileType)
	assert.Equal(t, os.FileMode(0750), sysRunStats.FileMode)
}

func TestUbuntuMountPersistentDisk(t *testing.T) {
	fakeStats, fakeFs, fakeCmdRunner, fakeDiskManager, fakeCompressor := getUbuntuDependencies()
	fakeFormatter := fakeDiskManager.FakeFormatter
	fakePartitioner := fakeDiskManager.FakePartitioner
	fakeMounter := fakeDiskManager.FakeMounter

	ubuntu := newUbuntuPlatform(fakeStats, fakeFs, fakeCmdRunner, fakeDiskManager, fakeCompressor)

	fakeFs.WriteToFile("/dev/vdf", "")

	err := ubuntu.MountPersistentDisk("/dev/sdf", "/mnt/point")
	assert.NoError(t, err)

	mountPoint := fakeFs.GetFileTestStat("/mnt/point")
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
	fakeStats, fakeFs, fakeCmdRunner, fakeDiskManager, fakeCompressor := getUbuntuDependencies()
	fakeMounter := fakeDiskManager.FakeMounter
	fakeMounter.UnmountDidUnmount = !isMounted

	ubuntu := newUbuntuPlatform(fakeStats, fakeFs, fakeCmdRunner, fakeDiskManager, fakeCompressor)

	fakeFs.WriteToFile("/dev/vdx", "")

	didUnmount, err := ubuntu.UnmountPersistentDisk("/dev/sdx")
	assert.NoError(t, err)
	assert.Equal(t, didUnmount, !isMounted)
	assert.Equal(t, "/dev/vdx1", fakeMounter.UnmountPartitionPath)
}

func TestUbuntuGetRealDevicePathWithMultiplePossibleDevices(t *testing.T) {
	fakeStats, fakeFs, fakeCmdRunner, fakeDiskManager, fakeCompressor := getUbuntuDependencies()
	ubuntu := newUbuntuPlatform(fakeStats, fakeFs, fakeCmdRunner, fakeDiskManager, fakeCompressor)

	fakeFs.WriteToFile("/dev/xvda", "")
	fakeFs.WriteToFile("/dev/vda", "")

	realPath, err := ubuntu.getRealDevicePath("/dev/sda")
	assert.NoError(t, err)
	assert.Equal(t, "/dev/xvda", realPath)
}

func TestUbuntuGetRealDevicePathWithDelayWithinTimeout(t *testing.T) {
	fakeStats, fakeFs, fakeCmdRunner, fakeDiskManager, fakeCompressor := getUbuntuDependencies()
	ubuntu := newUbuntuPlatform(fakeStats, fakeFs, fakeCmdRunner, fakeDiskManager, fakeCompressor)

	time.AfterFunc(time.Second, func() {
		fakeFs.WriteToFile("/dev/xvda", "")
	})

	realPath, err := ubuntu.getRealDevicePath("/dev/sda")
	assert.NoError(t, err)
	assert.Equal(t, "/dev/xvda", realPath)
}

func TestUbuntuGetRealDevicePathWithDelayBeyondTimeout(t *testing.T) {
	fakeStats, fakeFs, fakeCmdRunner, fakeDiskManager, fakeCompressor := getUbuntuDependencies()
	ubuntu := newUbuntuPlatform(fakeStats, fakeFs, fakeCmdRunner, fakeDiskManager, fakeCompressor)
	ubuntu.diskWaitTimeout = time.Second

	time.AfterFunc(2*time.Second, func() {
		fakeFs.WriteToFile("/dev/xvda", "")
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
	fakeStats, fakeFs, fakeCmdRunner, fakeDiskManager, fakeCompressor := getUbuntuDependencies()
	fakeStats.MemStats.Total = totalMemInMb * uint64(1024*1024)

	fakePartitioner := fakeDiskManager.FakePartitioner
	fakePartitioner.GetDeviceSizeInMbSizes = map[string]uint64{
		"/dev/hda": diskSizeInMb,
	}

	ubuntu := newUbuntuPlatform(fakeStats, fakeFs, fakeCmdRunner, fakeDiskManager, fakeCompressor)

	swapSize, linuxSize, err := ubuntu.calculateEphemeralDiskPartitionSizes("/dev/hda")

	assert.NoError(t, err)
	assert.Equal(t, expectedSwap, swapSize)
	assert.Equal(t, diskSizeInMb-expectedSwap, linuxSize)
}

func TestUbuntuMigratePersistentDisk(t *testing.T) {
	fakeStats, fakeFs, fakeCmdRunner, fakeDiskManager, fakeCompressor := getUbuntuDependencies()
	fakeMounter := fakeDiskManager.FakeMounter

	ubuntu := newUbuntuPlatform(fakeStats, fakeFs, fakeCmdRunner, fakeDiskManager, fakeCompressor)

	ubuntu.MigratePersistentDisk("/from/path", "/to/path")

	assert.Equal(t, fakeMounter.RemountAsReadonlyPath, "/from/path")

	assert.Equal(t, 1, len(fakeCmdRunner.RunCommands))
	assert.Equal(t, []string{"sh", "-c", "(tar -C /from/path -cf - .) | (tar -C /to/path -xpf -)"}, fakeCmdRunner.RunCommands[0])

	assert.Equal(t, fakeMounter.UnmountPartitionPath, "/from/path")
	assert.Equal(t, fakeMounter.RemountFromMountPoint, "/to/path")
	assert.Equal(t, fakeMounter.RemountToMountPoint, "/from/path")
}

func TestIsDevicePathMounted(t *testing.T) {
	fakeStats, fakeFs, fakeCmdRunner, fakeDiskManager, fakeCompressor := getUbuntuDependencies()

	fakeFs.WriteToFile("/dev/xvda", "")
	fakeMounter := fakeDiskManager.FakeMounter
	fakeMounter.IsMountedResult = true

	ubuntu := newUbuntuPlatform(fakeStats, fakeFs, fakeCmdRunner, fakeDiskManager, fakeCompressor)

	result, err := ubuntu.IsDevicePathMounted("/dev/sda")
	assert.NoError(t, err)
	assert.True(t, result)
	assert.Equal(t, fakeMounter.IsMountedDevicePathOrMountPoint, "/dev/xvda1")
}

func TestStartMonit(t *testing.T) {
	fakeStats, fakeFs, fakeCmdRunner, fakeDiskManager, fakeCompressor := getUbuntuDependencies()
	ubuntu := newUbuntuPlatform(fakeStats, fakeFs, fakeCmdRunner, fakeDiskManager, fakeCompressor)

	err := ubuntu.StartMonit()
	assert.NoError(t, err)
	assert.Equal(t, 1, len(fakeCmdRunner.RunCommands))
	assert.Equal(t, []string{"sv", "up", "monit"}, fakeCmdRunner.RunCommands[0])
}

func TestSetupMonitUserIfFileDoesNotExist(t *testing.T) {
	fakeStats, fakeFs, fakeCmdRunner, fakeDiskManager, fakeCompressor := getUbuntuDependencies()
	ubuntu := newUbuntuPlatform(fakeStats, fakeFs, fakeCmdRunner, fakeDiskManager, fakeCompressor)

	err := ubuntu.SetupMonitUser()
	assert.NoError(t, err)

	monitUserFileStats := fakeFs.GetFileTestStat("/var/vcap/monit/monit.user")
	assert.NotNil(t, monitUserFileStats)
	assert.Equal(t, "vcap:random-password", monitUserFileStats.Content)
}

func TestSetupMonitUserIfFileDoesExist(t *testing.T) {
	fakeStats, fakeFs, fakeCmdRunner, fakeDiskManager, fakeCompressor := getUbuntuDependencies()
	ubuntu := newUbuntuPlatform(fakeStats, fakeFs, fakeCmdRunner, fakeDiskManager, fakeCompressor)

	fakeFs.WriteToFile("/var/vcap/monit/monit.user", "vcap:other-random-password")

	err := ubuntu.SetupMonitUser()
	assert.NoError(t, err)

	monitUserFileStats := fakeFs.GetFileTestStat("/var/vcap/monit/monit.user")
	assert.NotNil(t, monitUserFileStats)
	assert.Equal(t, "vcap:other-random-password", monitUserFileStats.Content)
}

func TestGetMonitCredentialsReadsMonitFileFromDisk(t *testing.T) {
	fakeStats, fakeFs, fakeCmdRunner, fakeDiskManager, fakeCompressor := getUbuntuDependencies()
	ubuntu := newUbuntuPlatform(fakeStats, fakeFs, fakeCmdRunner, fakeDiskManager, fakeCompressor)

	fakeFs.WriteToFile("/var/vcap/monit/monit.user", "fake-user:fake-random-password")

	username, password, err := ubuntu.GetMonitCredentials()
	assert.NoError(t, err)

	assert.Equal(t, "fake-user", username)
	assert.Equal(t, "fake-random-password", password)
}

func TestGetMonitCredentialsErrsWhenInvalidFileFormat(t *testing.T) {
	fakeStats, fakeFs, fakeCmdRunner, fakeDiskManager, fakeCompressor := getUbuntuDependencies()
	ubuntu := newUbuntuPlatform(fakeStats, fakeFs, fakeCmdRunner, fakeDiskManager, fakeCompressor)

	fakeFs.WriteToFile("/var/vcap/monit/monit.user", "fake-user")

	_, _, err := ubuntu.GetMonitCredentials()
	assert.Error(t, err)
}

func TestGetMonitCredentialsLeavesColonsInPasswordIntact(t *testing.T) {
	fakeStats, fakeFs, fakeCmdRunner, fakeDiskManager, fakeCompressor := getUbuntuDependencies()
	ubuntu := newUbuntuPlatform(fakeStats, fakeFs, fakeCmdRunner, fakeDiskManager, fakeCompressor)

	fakeFs.WriteToFile("/var/vcap/monit/monit.user", "fake-user:fake:random:password")

	username, password, err := ubuntu.GetMonitCredentials()
	assert.NoError(t, err)

	assert.Equal(t, "fake-user", username)
	assert.Equal(t, "fake:random:password", password)
}

func getUbuntuDependencies() (
	collector *fakestats.FakeStatsCollector,
	fs *fakesys.FakeFileSystem,
	cmdRunner *fakesys.FakeCmdRunner,
	fakeDiskManager fakedisk.FakeDiskManager,
	fakeCompressor *fakecmd.FakeCompressor,
) {
	collector = &fakestats.FakeStatsCollector{}
	fs = &fakesys.FakeFileSystem{}
	cmdRunner = &fakesys.FakeCmdRunner{}
	fakeDiskManager = fakedisk.NewFakeDiskManager(cmdRunner)
	fakeCompressor = fakecmd.NewFakeCompressor()
	return
}
