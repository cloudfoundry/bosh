package platform

import (
	boshdisk "bosh/platform/disk"
	fakedisk "bosh/platform/disk/fakes"
	fakestats "bosh/platform/stats/fakes"
	boshsettings "bosh/settings"
	boshsys "bosh/system"
	fakesys "bosh/system/fakes"
	"fmt"
	"github.com/stretchr/testify/assert"
	"os"
	"path/filepath"
	"testing"
	"time"
)

func TestSetupRuntimeConfiguration(t *testing.T) {
	fakeStats, fakeFs, fakeCmdRunner, fakeDiskManager := getUbuntuDependencies()
	ubuntu := newUbuntuPlatform(fakeStats, fakeFs, fakeCmdRunner, fakeDiskManager)

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
	fakeStats, fakeFs, fakeCmdRunner, fakeDiskManager := getUbuntuDependencies()
	ubuntu := newUbuntuPlatform(fakeStats, fakeFs, fakeCmdRunner, fakeDiskManager)

	err := ubuntu.CreateUser("foo-user", password, "/some/path/to/home")
	assert.NoError(t, err)

	basePathStat := fakeFs.GetFileTestStat("/some/path/to/home")
	assert.Equal(t, fakesys.FakeFileTypeDir, basePathStat.FileType)
	assert.Equal(t, os.FileMode(0755), basePathStat.FileMode)

	assert.Equal(t, 1, len(fakeCmdRunner.RunCommands))
	assert.Equal(t, expectedUseradd, fakeCmdRunner.RunCommands[0])
}

func TestAddUserToGroups(t *testing.T) {
	fakeStats, fakeFs, fakeCmdRunner, fakeDiskManager := getUbuntuDependencies()
	ubuntu := newUbuntuPlatform(fakeStats, fakeFs, fakeCmdRunner, fakeDiskManager)

	err := ubuntu.AddUserToGroups("foo-user", []string{"group1", "group2", "group3"})
	assert.NoError(t, err)

	assert.Equal(t, 1, len(fakeCmdRunner.RunCommands))

	usermod := []string{"usermod", "-G", "group1,group2,group3", "foo-user"}
	assert.Equal(t, usermod, fakeCmdRunner.RunCommands[0])
}

func TestDeleteUsersWithPrefixAndRegex(t *testing.T) {
	fakeStats, fakeFs, fakeCmdRunner, fakeDiskManager := getUbuntuDependencies()

	passwdFile := fmt.Sprintf(`%sfoo:...
%sbar:...
foo:...
bar:...
foobar:...
%sfoobar:...`,
		boshsettings.EPHEMERAL_USER_PREFIX, boshsettings.EPHEMERAL_USER_PREFIX, boshsettings.EPHEMERAL_USER_PREFIX,
	)

	fakeFs.WriteToFile("/etc/passwd", passwdFile)

	ubuntu := newUbuntuPlatform(fakeStats, fakeFs, fakeCmdRunner, fakeDiskManager)

	err := ubuntu.DeleteEphemeralUsersMatching("bar$")
	assert.NoError(t, err)
	assert.Equal(t, 2, len(fakeCmdRunner.RunCommands))
	assert.Equal(t, []string{"userdel", "-r", "bosh_bar"}, fakeCmdRunner.RunCommands[0])
	assert.Equal(t, []string{"userdel", "-r", "bosh_foobar"}, fakeCmdRunner.RunCommands[1])
}

func TestUbuntuSetupSsh(t *testing.T) {
	fakeStats, fakeFs, fakeCmdRunner, fakeDiskManager := getUbuntuDependencies()
	fakeFs.HomeDirHomeDir = "/some/home/dir"

	ubuntu := newUbuntuPlatform(fakeStats, fakeFs, fakeCmdRunner, fakeDiskManager)
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
	fakeStats, fakeFs, fakeCmdRunner, fakeDiskManager := getUbuntuDependencies()
	ubuntu := newUbuntuPlatform(fakeStats, fakeFs, fakeCmdRunner, fakeDiskManager)

	ubuntu.SetUserPassword("my-user", "my-encrypted-password")
	assert.Equal(t, 1, len(fakeCmdRunner.RunCommands))
	assert.Equal(t, []string{"usermod", "-p", "my-encrypted-password", "my-user"}, fakeCmdRunner.RunCommands[0])
}

func TestUbuntuSetupHostname(t *testing.T) {
	fakeStats, fakeFs, fakeCmdRunner, fakeDiskManager := getUbuntuDependencies()
	ubuntu := newUbuntuPlatform(fakeStats, fakeFs, fakeCmdRunner, fakeDiskManager)

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
	fakeStats, fakeFs, fakeCmdRunner, fakeDiskManager := getUbuntuDependencies()
	testUbuntuSetupDhcp(t, fakeStats, fakeFs, fakeCmdRunner, fakeDiskManager)

	assert.Equal(t, len(fakeCmdRunner.RunCommands), 2)
	assert.Equal(t, fakeCmdRunner.RunCommands[0], []string{"pkill", "dhclient3"})
	assert.Equal(t, fakeCmdRunner.RunCommands[1], []string{"/etc/init.d/networking", "restart"})
}

func TestUbuntuSetupDhcpWithPreExistingConfiguration(t *testing.T) {
	fakeStats, fakeFs, fakeCmdRunner, fakeDiskManager := getUbuntuDependencies()
	fakeFs.WriteToFile("/etc/dhcp3/dhclient.conf", EXPECTED_DHCP_CONFIG)
	testUbuntuSetupDhcp(t, fakeStats, fakeFs, fakeCmdRunner, fakeDiskManager)

	assert.Equal(t, len(fakeCmdRunner.RunCommands), 0)
}

func testUbuntuSetupDhcp(t *testing.T, fakeStats *fakestats.FakeStatsCollector, fakeFs *fakesys.FakeFileSystem, fakeCmdRunner *fakesys.FakeCmdRunner, fakeDiskManager fakedisk.FakeDiskManager) {
	networks := boshsettings.Networks{
		"bosh": boshsettings.NetworkSettings{
			Default: []string{"dns"},
			Dns:     []string{"xx.xx.xx.xx", "yy.yy.yy.yy", "zz.zz.zz.zz"},
		},
		"vip": boshsettings.NetworkSettings{
			Default: []string{},
			Dns:     []string{"aa.aa.aa.aa"},
		},
	}

	ubuntu := newUbuntuPlatform(fakeStats, fakeFs, fakeCmdRunner, fakeDiskManager)
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

func TestUbuntuSetTimeWithNtpServers(t *testing.T) {
	fakeStats, fakeFs, fakeCmdRunner, fakeDiskManager := getUbuntuDependencies()
	ubuntu := newUbuntuPlatform(fakeStats, fakeFs, fakeCmdRunner, fakeDiskManager)

	ubuntu.SetTimeWithNtpServers([]string{"0.north-america.pool.ntp.org", "1.north-america.pool.ntp.org"}, "/var/vcap/bosh/etc/ntpserver")
	assert.Equal(t, 1, len(fakeCmdRunner.RunCommands))
	assert.Equal(t, []string{"ntpdate", "0.north-america.pool.ntp.org", "1.north-america.pool.ntp.org"}, fakeCmdRunner.RunCommands[0])

	ntpConfig := fakeFs.GetFileTestStat("/var/vcap/bosh/etc/ntpserver")
	assert.Equal(t, "0.north-america.pool.ntp.org 1.north-america.pool.ntp.org", ntpConfig.Content)
	assert.Equal(t, fakesys.FakeFileTypeFile, ntpConfig.FileType)
}

func TestUbuntuSetTimeWithNtpServersIsNoopWhenNoNtpServerProvided(t *testing.T) {
	fakeStats, fakeFs, fakeCmdRunner, fakeDiskManager := getUbuntuDependencies()
	ubuntu := newUbuntuPlatform(fakeStats, fakeFs, fakeCmdRunner, fakeDiskManager)

	ubuntu.SetTimeWithNtpServers([]string{}, "/foo/bar")
	assert.Equal(t, 0, len(fakeCmdRunner.RunCommands))

	ntpConfig := fakeFs.GetFileTestStat("/foo/bar")
	assert.Nil(t, ntpConfig)
}

func TestUbuntuSetupEphemeralDiskWithPath(t *testing.T) {
	fakeStats, fakeFs, fakeCmdRunner, fakeDiskManager := getUbuntuDependencies()
	fakeFormatter := fakeDiskManager.FakeFormatter
	fakePartitioner := fakeDiskManager.FakePartitioner
	fakeMounter := fakeDiskManager.FakeMounter

	fakePartitioner.GetDeviceSizeInMbSizes = map[string]uint64{"/dev/xvda": uint64(1024 * 1024 * 1024)}
	ubuntu := newUbuntuPlatform(fakeStats, fakeFs, fakeCmdRunner, fakeDiskManager)

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

func TestUbuntuGetRealDevicePathWithMultiplePossibleDevices(t *testing.T) {
	fakeStats, fakeFs, fakeCmdRunner, fakeDiskManager := getUbuntuDependencies()
	ubuntu := newUbuntuPlatform(fakeStats, fakeFs, fakeCmdRunner, fakeDiskManager)

	fakeFs.WriteToFile("/dev/xvda", "")
	fakeFs.WriteToFile("/dev/vda", "")

	realPath, err := ubuntu.getRealDevicePath("/dev/sda")
	assert.NoError(t, err)
	assert.Equal(t, "/dev/xvda", realPath)
}

func TestUbuntuGetRealDevicePathWithDelayWithinTimeout(t *testing.T) {
	fakeStats, fakeFs, fakeCmdRunner, fakeDiskManager := getUbuntuDependencies()
	ubuntu := newUbuntuPlatform(fakeStats, fakeFs, fakeCmdRunner, fakeDiskManager)

	time.AfterFunc(time.Second, func() {
		fakeFs.WriteToFile("/dev/xvda", "")
	})

	realPath, err := ubuntu.getRealDevicePath("/dev/sda")
	assert.NoError(t, err)
	assert.Equal(t, "/dev/xvda", realPath)
}

func TestUbuntuGetRealDevicePathWithDelayBeyondTimeout(t *testing.T) {
	fakeStats, fakeFs, fakeCmdRunner, fakeDiskManager := getUbuntuDependencies()
	ubuntu := newUbuntuPlatform(fakeStats, fakeFs, fakeCmdRunner, fakeDiskManager)
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
	fakeStats, fakeFs, fakeCmdRunner, fakeDiskManager := getUbuntuDependencies()

	fakeStats.MemStats.Total = totalMemInMb * uint64(1024*1024)

	fakePartitioner := fakeDiskManager.FakePartitioner
	fakePartitioner.GetDeviceSizeInMbSizes = map[string]uint64{
		"/dev/hda": diskSizeInMb,
	}

	ubuntu := newUbuntuPlatform(fakeStats, fakeFs, fakeCmdRunner, fakeDiskManager)

	swapSize, linuxSize, err := ubuntu.calculateEphemeralDiskPartitionSizes("/dev/hda")

	assert.NoError(t, err)
	assert.Equal(t, expectedSwap, swapSize)
	assert.Equal(t, diskSizeInMb-expectedSwap, linuxSize)
}

func TestStartMonit(t *testing.T) {
	fakeStats, fakeFs, fakeCmdRunner, fakeDiskManager := getUbuntuDependencies()
	ubuntu := newUbuntuPlatform(fakeStats, fakeFs, fakeCmdRunner, fakeDiskManager)

	err := ubuntu.StartMonit()
	assert.NoError(t, err)
	assert.Equal(t, 1, len(fakeCmdRunner.RunCommands))
	assert.Equal(t, []string{"sv", "up", "monit"}, fakeCmdRunner.RunCommands[0])
}

func TestCompressFilesInDir(t *testing.T) {
	fakeStats, _, _, fakeDiskManager := getUbuntuDependencies()
	osFs := boshsys.OsFileSystem{}
	execCmdRunner := boshsys.ExecCmdRunner{}

	tmpDir := filepath.Join(os.TempDir(), "TestCompressFilesInDir")
	err := osFs.MkdirAll(tmpDir, os.ModePerm)

	assert.NoError(t, err)
	defer os.RemoveAll(tmpDir)

	ubuntu := newUbuntuPlatform(fakeStats, osFs, execCmdRunner, fakeDiskManager)

	pwd, err := os.Getwd()
	assert.NoError(t, err)
	fixturesDir := filepath.Join(pwd, "..", "..", "..", "fixtures", "test_get_files_in_dir")

	tgz, err := ubuntu.CompressFilesInDir(fixturesDir, []string{"**/*.stdout.log", "*.stderr.log", "../some.config"})
	assert.NoError(t, err)

	defer os.Remove(tgz.Name())

	_, _, err = execCmdRunner.RunCommand("tar", "xzf", tgz.Name(), "-C", tmpDir)
	assert.NoError(t, err)

	content, err := osFs.ReadFile(tmpDir + "/app.stdout.log")
	assert.NoError(t, err)
	assert.Contains(t, content, "this is app stdout")

	content, err = osFs.ReadFile(tmpDir + "/app.stderr.log")
	assert.NoError(t, err)
	assert.Contains(t, content, "this is app stderr")

	content, err = osFs.ReadFile(tmpDir + "/other_logs/other_app.stdout.log")
	assert.NoError(t, err)
	assert.Contains(t, content, "this is other app stdout")

	content, err = osFs.ReadFile(tmpDir + "/other_logs/other_app.stderr.log")
	assert.Error(t, err)

	content, err = osFs.ReadFile(tmpDir + "/../some.config")
	assert.Error(t, err)
}

func getUbuntuDependencies() (collector *fakestats.FakeStatsCollector, fs *fakesys.FakeFileSystem, cmdRunner *fakesys.FakeCmdRunner, fakeDiskManager fakedisk.FakeDiskManager) {
	collector = &fakestats.FakeStatsCollector{}
	fs = &fakesys.FakeFileSystem{}
	cmdRunner = &fakesys.FakeCmdRunner{}
	fakeDiskManager = fakedisk.NewFakeDiskManager(cmdRunner)
	return
}
