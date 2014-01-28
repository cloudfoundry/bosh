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

func TestCentosSetupRuntimeConfiguration(t *testing.T) {
	deps, centos := buildCentos()

	err := centos.SetupRuntimeConfiguration()
	assert.NoError(t, err)

	assert.Equal(t, 1, len(deps.cmdRunner.RunCommands))
	assert.Equal(t, []string{"bosh-agent-rc"}, deps.cmdRunner.RunCommands[0])
}

func TestCentosCreateUser(t *testing.T) {
	expectedUseradd := []string{
		"useradd",
		"-m",
		"-b", "/some/path/to/home",
		"-s", "/bin/bash",
		"-p", "bar-pwd",
		"foo-user",
	}

	testCentosCreateUserWithPassword(t, "bar-pwd", expectedUseradd)
}

func TestCentosCreateUserWithAnEmptyPassword(t *testing.T) {
	expectedUseradd := []string{
		"useradd",
		"-m",
		"-b", "/some/path/to/home",
		"-s", "/bin/bash",
		"foo-user",
	}

	testCentosCreateUserWithPassword(t, "", expectedUseradd)
}

func testCentosCreateUserWithPassword(t *testing.T, password string, expectedUseradd []string) {
	deps, centos := buildCentos()

	err := centos.CreateUser("foo-user", password, "/some/path/to/home")
	assert.NoError(t, err)

	basePathStat := deps.fs.GetFileTestStat("/some/path/to/home")
	assert.Equal(t, fakesys.FakeFileTypeDir, basePathStat.FileType)
	assert.Equal(t, os.FileMode(0755), basePathStat.FileMode)

	assert.Equal(t, 1, len(deps.cmdRunner.RunCommands))
	assert.Equal(t, expectedUseradd, deps.cmdRunner.RunCommands[0])
}

func TestCentosAddUserToGroups(t *testing.T) {
	deps, centos := buildCentos()

	err := centos.AddUserToGroups("foo-user", []string{"group1", "group2", "group3"})
	assert.NoError(t, err)

	assert.Equal(t, 1, len(deps.cmdRunner.RunCommands))

	usermod := []string{"usermod", "-G", "group1,group2,group3", "foo-user"}
	assert.Equal(t, usermod, deps.cmdRunner.RunCommands[0])
}

func TestCentosDeleteUsersWithPrefixAndRegex(t *testing.T) {
	deps, centos := buildCentos()

	passwdFile := fmt.Sprintf(`%sfoo:...
%sbar:...
foo:...
bar:...
foobar:...
%sfoobar:...`,
		boshsettings.EPHEMERAL_USER_PREFIX, boshsettings.EPHEMERAL_USER_PREFIX, boshsettings.EPHEMERAL_USER_PREFIX,
	)

	deps.fs.WriteToFile("/etc/passwd", passwdFile)

	err := centos.DeleteEphemeralUsersMatching("bar$")
	assert.NoError(t, err)
	assert.Equal(t, 2, len(deps.cmdRunner.RunCommands))
	assert.Equal(t, []string{"userdel", "-r", "bosh_bar"}, deps.cmdRunner.RunCommands[0])
	assert.Equal(t, []string{"userdel", "-r", "bosh_foobar"}, deps.cmdRunner.RunCommands[1])
}

func TestCentosSetupSsh(t *testing.T) {
	deps, centos := buildCentos()
	deps.fs.HomeDirHomePath = "/some/home/dir"

	centos.SetupSsh("some public key", "vcap")

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

func TestCentosSetUserPassword(t *testing.T) {
	deps, centos := buildCentos()

	centos.SetUserPassword("my-user", "my-encrypted-password")
	assert.Equal(t, 1, len(deps.cmdRunner.RunCommands))
	assert.Equal(t, []string{"usermod", "-p", "my-encrypted-password", "my-user"}, deps.cmdRunner.RunCommands[0])
}

func TestCentosSetupHostname(t *testing.T) {
	deps, centos := buildCentos()

	centos.SetupHostname("foobar.local")
	assert.Equal(t, 1, len(deps.cmdRunner.RunCommands))
	assert.Equal(t, []string{"hostname", "foobar.local"}, deps.cmdRunner.RunCommands[0])

	hostnameFileContent, err := deps.fs.ReadFile("/etc/hostname")
	assert.NoError(t, err)
	assert.Equal(t, "foobar.local", hostnameFileContent)

	hostsFileContent, err := deps.fs.ReadFile("/etc/hosts")
	assert.NoError(t, err)
	assert.Equal(t, CENTOS_EXPECTED_ETC_HOSTS, hostsFileContent)
}

const CENTOS_EXPECTED_ETC_HOSTS = `127.0.0.1 localhost foobar.local

# The following lines are desirable for IPv6 capable hosts
::1 localhost ip6-localhost ip6-loopback foobar.local
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
ff02::3 ip6-allhosts
`

func TestCentosSetupDhcp(t *testing.T) {
	deps, centos := buildCentos()
	testCentosSetupDhcp(t, deps, centos)

	assert.Equal(t, len(deps.cmdRunner.RunCommands), 1)
	assert.Equal(t, deps.cmdRunner.RunCommands[0], []string{"service", "network", "restart"})
}

func TestCentosSetupDhcpWithPreExistingConfiguration(t *testing.T) {
	deps, centos := buildCentos()
	deps.fs.WriteToFile("/etc/dhcp/dhclient.conf", CENTOS_EXPECTED_DHCP_CONFIG)
	testCentosSetupDhcp(t, deps, centos)

	assert.Equal(t, len(deps.cmdRunner.RunCommands), 0)
}

func testCentosSetupDhcp(
	t *testing.T,
	deps centosDependencies,
	platform centos,
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

	dhcpConfig := deps.fs.GetFileTestStat("/etc/dhcp/dhclient.conf")
	assert.NotNil(t, dhcpConfig)
	assert.Equal(t, dhcpConfig.Content, CENTOS_EXPECTED_DHCP_CONFIG)
}

const CENTOS_EXPECTED_DHCP_CONFIG = `# Generated by bosh-agent

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

func TestCentosSetupLogrotate(t *testing.T) {
	deps, centos := buildCentos()

	centos.SetupLogrotate("fake-group-name", "fake-base-path", "fake-size")

	logrotateFileContent, err := deps.fs.ReadFile("/etc/logrotate.d/fake-group-name")
	assert.NoError(t, err)
	assert.Equal(t, CENTOS_EXPECTED_ETC_LOGROTATE, logrotateFileContent)
}

const CENTOS_EXPECTED_ETC_LOGROTATE = `# Generated by bosh-agent

fake-base-path/data/sys/log/*.log fake-base-path/data/sys/log/*/*.log fake-base-path/data/sys/log/*/*/*.log {
  missingok
  rotate 7
  compress
  delaycompress
  copytruncate
  size=fake-size
}
`

func TestCentosSetTimeWithNtpServers(t *testing.T) {
	deps, centos := buildCentos()

	centos.SetTimeWithNtpServers([]string{"0.north-america.pool.ntp.org", "1.north-america.pool.ntp.org"})

	ntpConfig := deps.fs.GetFileTestStat("/fake-dir/bosh/etc/ntpserver")
	assert.Equal(t, "0.north-america.pool.ntp.org 1.north-america.pool.ntp.org", ntpConfig.Content)
	assert.Equal(t, fakesys.FakeFileTypeFile, ntpConfig.FileType)

	assert.Equal(t, 1, len(deps.cmdRunner.RunCommands))
	assert.Equal(t, []string{"ntpdate"}, deps.cmdRunner.RunCommands[0])
}

func TestCentosSetTimeWithNtpServersIsNoopWhenNoNtpServerProvided(t *testing.T) {
	deps, centos := buildCentos()

	centos.SetTimeWithNtpServers([]string{})
	assert.Equal(t, 0, len(deps.cmdRunner.RunCommands))

	ntpConfig := deps.fs.GetFileTestStat("/fake-dir/bosh/etc/ntpserver")
	assert.Nil(t, ntpConfig)
}

func TestCentosSetupEphemeralDiskWithPath(t *testing.T) {
	deps, centos := buildCentos()
	fakeFormatter := deps.diskManager.FakeFormatter
	fakePartitioner := deps.diskManager.FakePartitioner
	fakeMounter := deps.diskManager.FakeMounter

	fakePartitioner.GetDeviceSizeInMbSizes = map[string]uint64{"/dev/xvda": uint64(1024 * 1024 * 1024)}

	deps.fs.WriteToFile("/dev/xvda", "")

	err := centos.SetupEphemeralDiskWithPath("/dev/sda")
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

func TestCentosSetupTmpDir(t *testing.T) {
	deps, centos := buildCentos()

	err := centos.SetupTmpDir()
	assert.NoError(t, err)

	assert.Equal(t, 2, len(deps.cmdRunner.RunCommands))

	assert.Equal(t, []string{"chown", "root:vcap", "/tmp"}, deps.cmdRunner.RunCommands[0])
	assert.Equal(t, []string{"chmod", "0770", "/tmp"}, deps.cmdRunner.RunCommands[1])
}

func TestCentosMountPersistentDisk(t *testing.T) {
	deps, centos := buildCentos()
	fakeFormatter := deps.diskManager.FakeFormatter
	fakePartitioner := deps.diskManager.FakePartitioner
	fakeMounter := deps.diskManager.FakeMounter

	deps.fs.WriteToFile("/dev/vdf", "")

	err := centos.MountPersistentDisk("/dev/sdf", "/mnt/point")
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

func TestCentosUnmountPersistentDiskWhenNotMounted(t *testing.T) {
	testCentosUnmountPersistentDisk(t, false)
}

func TestCentosUnmountPersistentDiskWhenAlreadyMounted(t *testing.T) {
	testCentosUnmountPersistentDisk(t, true)
}

func testCentosUnmountPersistentDisk(t *testing.T, isMounted bool) {
	deps, centos := buildCentos()
	fakeMounter := deps.diskManager.FakeMounter
	fakeMounter.UnmountDidUnmount = !isMounted

	deps.fs.WriteToFile("/dev/vdx", "")

	didUnmount, err := centos.UnmountPersistentDisk("/dev/sdx")
	assert.NoError(t, err)
	assert.Equal(t, didUnmount, !isMounted)
	assert.Equal(t, "/dev/vdx1", fakeMounter.UnmountPartitionPath)
}

func TestCentosGetRealDevicePathWithMultiplePossibleDevices(t *testing.T) {
	deps, centos := buildCentos()

	deps.fs.WriteToFile("/dev/xvda", "")
	deps.fs.WriteToFile("/dev/vda", "")

	realPath, err := centos.getRealDevicePath("/dev/sda")
	assert.NoError(t, err)
	assert.Equal(t, "/dev/xvda", realPath)
}

func TestCentosGetRealDevicePathWithDelayWithinTimeout(t *testing.T) {
	deps, centos := buildCentos()

	time.AfterFunc(time.Second, func() {
		deps.fs.WriteToFile("/dev/xvda", "")
	})

	realPath, err := centos.getRealDevicePath("/dev/sda")
	assert.NoError(t, err)
	assert.Equal(t, "/dev/xvda", realPath)
}

func TestCentosGetRealDevicePathWithDelayBeyondTimeout(t *testing.T) {
	deps, centos := buildCentos()

	centos.diskWaitTimeout = time.Second

	time.AfterFunc(2*time.Second, func() {
		deps.fs.WriteToFile("/dev/xvda", "")
	})

	_, err := centos.getRealDevicePath("/dev/sda")
	assert.Error(t, err)
}

func TestCentosCalculateEphemeralDiskPartitionSizesWhenDiskIsBiggerThanTwiceTheMemory(t *testing.T) {
	totalMemInMb := uint64(1024)

	diskSizeInMb := totalMemInMb*2 + 64
	expectedSwap := totalMemInMb
	testCentosCalculateEphemeralDiskPartitionSizes(t, totalMemInMb, diskSizeInMb, expectedSwap)
}

func TestCentosCalculateEphemeralDiskPartitionSizesWhenDiskTwiceTheMemoryOrSmaller(t *testing.T) {
	totalMemInMb := uint64(1024)

	diskSizeInMb := totalMemInMb*2 - 64
	expectedSwap := diskSizeInMb / 2
	testCentosCalculateEphemeralDiskPartitionSizes(t, totalMemInMb, diskSizeInMb, expectedSwap)
}

func testCentosCalculateEphemeralDiskPartitionSizes(t *testing.T, totalMemInMb, diskSizeInMb, expectedSwap uint64) {
	deps, centos := buildCentos()
	deps.collector.MemStats.Total = totalMemInMb * uint64(1024*1024)

	fakePartitioner := deps.diskManager.FakePartitioner
	fakePartitioner.GetDeviceSizeInMbSizes = map[string]uint64{
		"/dev/hda": diskSizeInMb,
	}

	swapSize, linuxSize, err := centos.calculateEphemeralDiskPartitionSizes("/dev/hda")

	assert.NoError(t, err)
	assert.Equal(t, expectedSwap, swapSize)
	assert.Equal(t, diskSizeInMb-expectedSwap, linuxSize)
}

func TestCentosMigratePersistentDisk(t *testing.T) {
	deps, centos := buildCentos()
	fakeMounter := deps.diskManager.FakeMounter

	centos.MigratePersistentDisk("/from/path", "/to/path")

	assert.Equal(t, fakeMounter.RemountAsReadonlyPath, "/from/path")

	assert.Equal(t, 1, len(deps.cmdRunner.RunCommands))
	assert.Equal(t, []string{"sh", "-c", "(tar -C /from/path -cf - .) | (tar -C /to/path -xpf -)"}, deps.cmdRunner.RunCommands[0])

	assert.Equal(t, fakeMounter.UnmountPartitionPath, "/from/path")
	assert.Equal(t, fakeMounter.RemountFromMountPoint, "/to/path")
	assert.Equal(t, fakeMounter.RemountToMountPoint, "/from/path")
}

func TestCentosGetFileContentsFromCDROM(t *testing.T) {
	deps, centos := buildCentos()

	deps.fs.WriteToFile("/dev/bosh-cdrom", "")
	settingsPath := filepath.Join(centos.dirProvider.SettingsDir(), "env")
	deps.fs.WriteToFile(settingsPath, "some stuff")
	deps.fs.WriteToFile("/proc/sys/dev/cdrom/info", "CD-ROM information, Id: cdrom.c 3.20 2003/12/17\n\ndrive name:		sr0\ndrive speed:		32\n")

	contents, err := centos.GetFileContentsFromCDROM("env")
	assert.NoError(t, err)

	assert.Equal(t, 3, len(deps.cmdRunner.RunCommands))
	assert.Equal(t, []string{"mount", "/dev/sr0", "/fake-dir/bosh/settings"}, deps.cmdRunner.RunCommands[0])
	assert.Equal(t, []string{"umount", "/fake-dir/bosh/settings"}, deps.cmdRunner.RunCommands[1])
	assert.Equal(t, []string{"eject", "/dev/sr0"}, deps.cmdRunner.RunCommands[2])

	assert.Equal(t, contents, []byte("some stuff"))
}

func TestCentosGetFileContentsFromCDROMWhenCDROMFailedToLoad(t *testing.T) {
	deps, centos := buildCentos()

	deps.fs.WriteToFile("/dev/sr0/env", "some stuff")
	deps.fs.WriteToFile("/proc/sys/dev/cdrom/info", "CD-ROM information, Id: cdrom.c 3.20 2003/12/17\n\ndrive name:		sr0\ndrive speed:		32\n")
	centos.cdromWaitInterval = 1 * time.Millisecond

	_, err := centos.GetFileContentsFromCDROM("env")
	assert.Error(t, err)
}

func TestCentosGetFileContentsFromCDROMRetriesCDROMReading(t *testing.T) {
	deps, centos := buildCentos()

	settingsPath := filepath.Join(centos.dirProvider.SettingsDir(), "env")
	deps.fs.WriteToFile(settingsPath, "some stuff")
	deps.fs.WriteToFile("/proc/sys/dev/cdrom/info", "CD-ROM information, Id: cdrom.c 3.20 2003/12/17\n\ndrive name:		sr0\ndrive speed:		32\n")

	go func() {
		_, err := centos.GetFileContentsFromCDROM("env")
		assert.NoError(t, err)
	}()

	time.Sleep(500 * time.Millisecond)
	deps.fs.WriteToFile("/dev/bosh-cdrom", "")
}

func TestCentosIsDevicePathMounted(t *testing.T) {
	deps, centos := buildCentos()

	deps.fs.WriteToFile("/dev/xvda", "")
	fakeMounter := deps.diskManager.FakeMounter
	fakeMounter.IsMountedResult = true

	result, err := centos.IsDevicePathMounted("/dev/sda")
	assert.NoError(t, err)
	assert.True(t, result)
	assert.Equal(t, fakeMounter.IsMountedDevicePathOrMountPoint, "/dev/xvda1")
}

func TestCentosStartMonit(t *testing.T) {
	deps, centos := buildCentos()

	err := centos.StartMonit()
	assert.NoError(t, err)
	assert.Equal(t, 1, len(deps.cmdRunner.RunCommands))
	assert.Equal(t, []string{"sv", "up", "monit"}, deps.cmdRunner.RunCommands[0])
}

func TestCentosSetupMonitUserIfFileDoesNotExist(t *testing.T) {
	deps, centos := buildCentos()

	err := centos.SetupMonitUser()
	assert.NoError(t, err)

	monitUserFileStats := deps.fs.GetFileTestStat("/fake-dir/monit/monit.user")
	assert.NotNil(t, monitUserFileStats)
	assert.Equal(t, "vcap:random-password", monitUserFileStats.Content)
}

func TestCentosSetupMonitUserIfFileDoesExist(t *testing.T) {
	deps, centos := buildCentos()

	deps.fs.WriteToFile("/fake-dir/monit/monit.user", "vcap:other-random-password")

	err := centos.SetupMonitUser()
	assert.NoError(t, err)

	monitUserFileStats := deps.fs.GetFileTestStat("/fake-dir/monit/monit.user")
	assert.NotNil(t, monitUserFileStats)
	assert.Equal(t, "vcap:other-random-password", monitUserFileStats.Content)
}

func TestCentosGetMonitCredentialsReadsMonitFileFromDisk(t *testing.T) {
	deps, centos := buildCentos()

	deps.fs.WriteToFile("/fake-dir/monit/monit.user", "fake-user:fake-random-password")

	username, password, err := centos.GetMonitCredentials()
	assert.NoError(t, err)

	assert.Equal(t, "fake-user", username)
	assert.Equal(t, "fake-random-password", password)
}

func TestCentosGetMonitCredentialsErrsWhenInvalidFileFormat(t *testing.T) {
	deps, centos := buildCentos()

	deps.fs.WriteToFile("/fake-dir/monit/monit.user", "fake-user")

	_, _, err := centos.GetMonitCredentials()
	assert.Error(t, err)
}

func TestCentosGetMonitCredentialsLeavesColonsInPasswordIntact(t *testing.T) {
	deps, centos := buildCentos()
	deps.fs.WriteToFile("/fake-dir/monit/monit.user", "fake-user:fake:random:password")

	username, password, err := centos.GetMonitCredentials()
	assert.NoError(t, err)

	assert.Equal(t, "fake-user", username)
	assert.Equal(t, "fake:random:password", password)
}

type centosDependencies struct {
	collector   *fakestats.FakeStatsCollector
	fs          *fakesys.FakeFileSystem
	cmdRunner   *fakesys.FakeCmdRunner
	diskManager fakedisk.FakeDiskManager
	dirProvider boshdirs.DirectoriesProvider
}

func buildCentos() (
	deps centosDependencies,
	platform centos,
) {
	deps.collector = &fakestats.FakeStatsCollector{}
	deps.fs = &fakesys.FakeFileSystem{}
	deps.cmdRunner = &fakesys.FakeCmdRunner{}
	deps.diskManager = fakedisk.NewFakeDiskManager(deps.cmdRunner)
	deps.dirProvider = boshdirs.NewDirectoriesProvider("/fake-dir")

	platform = newCentosPlatform(
		deps.collector,
		deps.fs,
		deps.cmdRunner,
		deps.diskManager,
		deps.dirProvider,
	)
	return
}
