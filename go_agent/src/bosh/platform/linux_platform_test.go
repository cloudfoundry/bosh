package platform_test

import (
	boshdevicepathresolver "bosh/infrastructure/device_path_resolver"
	. "bosh/platform"
	fakecd "bosh/platform/cdutil/fakes"
	boshcmd "bosh/platform/commands"
	boshdisk "bosh/platform/disk"
	fakedisk "bosh/platform/disk/fakes"
	boshnet "bosh/platform/net"
	fakestats "bosh/platform/stats/fakes"
	boshvitals "bosh/platform/vitals"
	boshdirs "bosh/settings/directories"
	fakesys "bosh/system/fakes"
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
	"os"
	"path/filepath"
	"time"
)

var _ = Describe("LinuxPlatform", func() {
	Describe("LookupScsiDisk", func() {
		var (
			collector       *fakestats.FakeStatsCollector
			fs              *fakesys.FakeFileSystem
			cmdRunner       *fakesys.FakeCmdRunner
			diskManager     *fakedisk.FakeDiskManager
			dirProvider     boshdirs.DirectoriesProvider
			diskWaitTimeout time.Duration
			platform        Platform
			cdutil          *fakecd.FakeCdUtil
			compressor      boshcmd.Compressor
			copier          boshcmd.Copier
			vitalsService   boshvitals.Service
		)

		const sleepInterval = time.Millisecond * 5

		BeforeEach(func() {
			collector = &fakestats.FakeStatsCollector{}
			fs = fakesys.NewFakeFileSystem()
			cmdRunner = &fakesys.FakeCmdRunner{}
			diskManager = fakedisk.NewFakeDiskManager()
			dirProvider = boshdirs.NewDirectoriesProvider("/fake-dir")
			diskWaitTimeout = 1 * time.Millisecond
			cdutil = fakecd.NewFakeCdUtil()
			compressor = boshcmd.NewTarballCompressor(cmdRunner, fs)
			copier = boshcmd.NewCpCopier(cmdRunner, fs)
			vitalsService = boshvitals.NewService(collector, dirProvider)
			fs.SetGlob("/sys/bus/scsi/devices/*:0:0:0/block/*", []string{
				"/sys/bus/scsi/devices/0:0:0:0/block/sr0",
				"/sys/bus/scsi/devices/6:0:0:0/block/sdd",
				"/sys/bus/scsi/devices/fake-host-id:0:0:0/block/sda",
			})
			fs.SetGlob("/sys/bus/scsi/devices/fake-host-id:0:fake-disk-id:0/block/*",
				[]string{"/sys/bus/scsi/devices/fake-host-id:0:fake-disk-id:0/block/sdf"})
		})

		JustBeforeEach(func() {
			netManager := boshnet.NewCentosNetManager(fs, cmdRunner, 1*time.Millisecond)

			platform = NewLinuxPlatform(
				fs,
				cmdRunner,
				collector,
				compressor,
				copier,
				dirProvider,
				vitalsService,
				cdutil,
				diskManager,
				netManager,
				sleepInterval,
				boshdevicepathresolver.NewDevicePathResolver(diskWaitTimeout, fs),
			)
		})

		Describe("LookupScsiDisk", func() {
			It("rescans the devices attached to the root disks scsi controller", func() {
				platform.LookupScsiDisk("fake-disk-id")

				scanContents, err := fs.ReadFileString("/sys/class/scsi_host/hostfake-host-id/scan")
				Expect(err).NotTo(HaveOccurred())
				Expect(scanContents).To(Equal("- - -"))
			})

			It("detects device", func() {
				devicePath, found := platform.LookupScsiDisk("fake-disk-id")
				Expect(found).To(Equal(true))
				Expect(devicePath).To(Equal("/sys/bus/scsi/devices/fake-host-id:0:fake-disk-id:0/block/sdf"))
			})

			Context("when device does not immediately appear", func() {
				It("retries detection of device", func() {
					fs.SetGlob("/sys/bus/scsi/devices/fake-host-id:0:fake-disk-id:0/block/*",
						[]string{},
						[]string{},
						[]string{},
						[]string{},
						[]string{},
						[]string{"/sys/bus/scsi/devices/fake-host-id:0:fake-disk-id:0/block/sdf"},
					)

					startTime := time.Now()
					devicePath, found := platform.LookupScsiDisk("fake-disk-id")
					runningTime := time.Since(startTime)
					Expect(found).To(Equal(true))
					Expect(runningTime >= sleepInterval*5).To(BeTrue())
					Expect(devicePath).To(Equal("/sys/bus/scsi/devices/fake-host-id:0:fake-disk-id:0/block/sdf"))
				})
			})

			Context("when device never appears", func() {
				It("returns not found", func() {
					fs.SetGlob("/sys/bus/scsi/devices/fake-host-id:0:fake-disk-id:0/block/*", []string{})
					_, found := platform.LookupScsiDisk("fake-disk-id")
					Expect(found).To(Equal(false))
				})
			})
		})

		Describe("SetupRuntimeConfiguration", func() {
			It("setups runtime configuration", func() {
				err := platform.SetupRuntimeConfiguration()
				Expect(err).NotTo(HaveOccurred())

				Expect(len(cmdRunner.RunCommands)).To(Equal(1))
				Expect(cmdRunner.RunCommands[0]).To(Equal([]string{"bosh-agent-rc"}))
			})
		})

		Describe("CreateUser", func() {
			It("creates user", func() {
				expectedUseradd := []string{
					"useradd",
					"-m",
					"-b", "/some/path/to/home",
					"-s", "/bin/bash",
					"-p", "bar-pwd",
					"foo-user",
				}

				err := platform.CreateUser("foo-user", "bar-pwd", "/some/path/to/home")
				Expect(err).NotTo(HaveOccurred())

				basePathStat := fs.GetFileTestStat("/some/path/to/home")
				Expect(basePathStat.FileType).To(Equal(fakesys.FakeFileTypeDir))
				Expect(basePathStat.FileMode).To(Equal(os.FileMode(0755)))

				Expect(cmdRunner.RunCommands).To(Equal([][]string{expectedUseradd}))
			})

			It("creates user with an empty password", func() {
				expectedUseradd := []string{
					"useradd",
					"-m",
					"-b", "/some/path/to/home",
					"-s", "/bin/bash",
					"foo-user",
				}

				err := platform.CreateUser("foo-user", "", "/some/path/to/home")
				Expect(err).NotTo(HaveOccurred())

				basePathStat := fs.GetFileTestStat("/some/path/to/home")
				Expect(basePathStat.FileType).To(Equal(fakesys.FakeFileTypeDir))
				Expect(basePathStat.FileMode).To(Equal(os.FileMode(0755)))

				Expect(cmdRunner.RunCommands).To(Equal([][]string{expectedUseradd}))
			})
		})
		Describe("AddUserToGroups", func() {
			It("adds user to groups", func() {
				err := platform.AddUserToGroups("foo-user", []string{"group1", "group2", "group3"})
				Expect(err).NotTo(HaveOccurred())

				Expect(len(cmdRunner.RunCommands)).To(Equal(1))

				usermod := []string{"usermod", "-G", "group1,group2,group3", "foo-user"}
				Expect(cmdRunner.RunCommands[0]).To(Equal(usermod))
			})
		})

		Describe("DeleteEphemeralUsersMatching", func() {
			It("deletes users with prefix and regex", func() {
				passwdFile := `bosh_foo:...
bosh_bar:...
foo:...
bar:...
foobar:...
bosh_foobar:...`

				fs.WriteFileString("/etc/passwd", passwdFile)

				err := platform.DeleteEphemeralUsersMatching("bar$")
				Expect(err).NotTo(HaveOccurred())
				Expect(len(cmdRunner.RunCommands)).To(Equal(2))
				Expect(cmdRunner.RunCommands[0]).To(Equal([]string{"userdel", "-r", "bosh_bar"}))
				Expect(cmdRunner.RunCommands[1]).To(Equal([]string{"userdel", "-r", "bosh_foobar"}))
			})
		})
		Describe("SetupSsh", func() {
			It("setup ssh", func() {
				fs.HomeDirHomePath = "/some/home/dir"

				platform.SetupSsh("some public key", "vcap")

				sshDirPath := "/some/home/dir/.ssh"
				sshDirStat := fs.GetFileTestStat(sshDirPath)

				Expect("vcap").To(Equal(fs.HomeDirUsername))

				Expect(sshDirStat).NotTo(BeNil())
				Expect(sshDirStat.FileType).To(Equal(fakesys.FakeFileTypeDir))
				Expect(os.FileMode(0700)).To(Equal(sshDirStat.FileMode))
				Expect("vcap").To(Equal(sshDirStat.Username))

				authKeysStat := fs.GetFileTestStat(filepath.Join(sshDirPath, "authorized_keys"))

				Expect(authKeysStat).NotTo(BeNil())
				Expect(fakesys.FakeFileTypeFile).To(Equal(authKeysStat.FileType))
				Expect(os.FileMode(0600)).To(Equal(authKeysStat.FileMode))
				Expect("vcap").To(Equal(authKeysStat.Username))
				Expect("some public key").To(Equal(authKeysStat.StringContents()))
			})

		})

		Describe("SetUserPassword", func() {
			It("set user password", func() {
				platform.SetUserPassword("my-user", "my-encrypted-password")
				Expect(len(cmdRunner.RunCommands)).To(Equal(1))
				Expect(cmdRunner.RunCommands[0]).To(Equal([]string{"usermod", "-p", "my-encrypted-password", "my-user"}))
			})
		})

		Describe("SetupHostname", func() {
			const EXPECTED_ETC_HOSTS = `127.0.0.1 localhost foobar.local

# The following lines are desirable for IPv6 capable hosts
::1 localhost ip6-localhost ip6-loopback foobar.local
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
ff02::3 ip6-allhosts
`
			It("sets up hostname", func() {
				platform.SetupHostname("foobar.local")
				Expect(len(cmdRunner.RunCommands)).To(Equal(1))
				Expect(cmdRunner.RunCommands[0]).To(Equal([]string{"hostname", "foobar.local"}))

				hostnameFileContent, err := fs.ReadFileString("/etc/hostname")
				Expect(err).NotTo(HaveOccurred())
				Expect(hostnameFileContent).To(Equal("foobar.local"))

				hostsFileContent, err := fs.ReadFileString("/etc/hosts")
				Expect(err).NotTo(HaveOccurred())
				Expect(hostsFileContent).To(Equal(EXPECTED_ETC_HOSTS))
			})

		})

		Describe("SetupLogrotate", func() {
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

			It("sets up logrotate", func() {
				platform.SetupLogrotate("fake-group-name", "fake-base-path", "fake-size")

				logrotateFileContent, err := fs.ReadFileString("/etc/logrotate.d/fake-group-name")
				Expect(err).NotTo(HaveOccurred())
				Expect(logrotateFileContent).To(Equal(EXPECTED_ETC_LOGROTATE))
			})
		})

		Describe("SetTimeWithNtpServers", func() {
			It("sets time with ntp servers", func() {
				platform.SetTimeWithNtpServers([]string{"0.north-america.pool.ntp.org", "1.north-america.pool.ntp.org"})

				ntpConfig := fs.GetFileTestStat("/fake-dir/bosh/etc/ntpserver")
				Expect(ntpConfig.StringContents()).To(Equal("0.north-america.pool.ntp.org 1.north-america.pool.ntp.org"))
				Expect(ntpConfig.FileType).To(Equal(fakesys.FakeFileTypeFile))

				Expect(len(cmdRunner.RunCommands)).To(Equal(1))
				Expect(cmdRunner.RunCommands[0]).To(Equal([]string{"ntpdate"}))
			})

			It("sets time with ntp servers is noop when no ntp server provided", func() {
				platform.SetTimeWithNtpServers([]string{})
				Expect(len(cmdRunner.RunCommands)).To(Equal(0))

				ntpConfig := fs.GetFileTestStat("/fake-dir/bosh/etc/ntpserver")
				Expect(ntpConfig).To(BeNil())
			})
		})

		Describe("SetupEphemeralDiskWithPath", func() {
			It("sets up ephemeral disk with path", func() {
				fakeFormatter := diskManager.FakeFormatter
				fakePartitioner := diskManager.FakePartitioner
				fakeMounter := diskManager.FakeMounter

				fakePartitioner.GetDeviceSizeInMbSizes = map[string]uint64{"/dev/xvda": uint64(1024 * 1024 * 1024)}

				fs.WriteFile("/dev/xvda", []byte{})

				err := platform.SetupEphemeralDiskWithPath("/dev/xvda")
				Expect(err).NotTo(HaveOccurred())

				dataDir := fs.GetFileTestStat("/fake-dir/data")
				Expect(dataDir.FileType).To(Equal(fakesys.FakeFileTypeDir))
				Expect(dataDir.FileMode).To(Equal(os.FileMode(0750)))

				Expect(fakePartitioner.PartitionDevicePath).To(Equal("/dev/xvda"))
				Expect(len(fakePartitioner.PartitionPartitions)).To(Equal(2))

				swapPartition := fakePartitioner.PartitionPartitions[0]
				ext4Partition := fakePartitioner.PartitionPartitions[1]

				Expect(swapPartition.Type).To(Equal(boshdisk.PartitionTypeSwap))
				Expect(ext4Partition.Type).To(Equal(boshdisk.PartitionTypeLinux))

				Expect(len(fakeFormatter.FormatPartitionPaths)).To(Equal(2))
				Expect(fakeFormatter.FormatPartitionPaths[0]).To(Equal("/dev/xvda1"))
				Expect(fakeFormatter.FormatPartitionPaths[1]).To(Equal("/dev/xvda2"))

				Expect(len(fakeFormatter.FormatFsTypes)).To(Equal(2))
				Expect(fakeFormatter.FormatFsTypes[0]).To(Equal(boshdisk.FileSystemSwap))
				Expect(fakeFormatter.FormatFsTypes[1]).To(Equal(boshdisk.FileSystemExt4))

				Expect(len(fakeMounter.MountMountPoints)).To(Equal(1))
				Expect(fakeMounter.MountMountPoints[0]).To(Equal("/fake-dir/data"))
				Expect(len(fakeMounter.MountPartitionPaths)).To(Equal(1))
				Expect(fakeMounter.MountPartitionPaths[0]).To(Equal("/dev/xvda2"))

				Expect(len(fakeMounter.SwapOnPartitionPaths)).To(Equal(1))
				Expect(fakeMounter.SwapOnPartitionPaths[0]).To(Equal("/dev/xvda1"))

				sysLogStats := fs.GetFileTestStat("/fake-dir/data/sys/log")
				Expect(sysLogStats).ToNot(BeNil())
				Expect(sysLogStats.FileType).To(Equal(fakesys.FakeFileTypeDir))
				Expect(sysLogStats.FileMode).To(Equal(os.FileMode(0750)))
				Expect(cmdRunner.RunCommands[0]).To(Equal([]string{"chown", "root:vcap", "/fake-dir/data/sys"}))
				Expect(cmdRunner.RunCommands[1]).To(Equal([]string{"chown", "root:vcap", "/fake-dir/data/sys/log"}))

				sysRunStats := fs.GetFileTestStat("/fake-dir/data/sys/run")
				Expect(sysRunStats).ToNot(BeNil())
				Expect(sysRunStats.FileType).To(Equal(fakesys.FakeFileTypeDir))
				Expect(sysRunStats.FileMode).To(Equal(os.FileMode(0750)))
				Expect(cmdRunner.RunCommands[2]).To(Equal([]string{"chown", "root:vcap", "/fake-dir/data/sys/run"}))
			})

			It("calculates ephemeral disk partition sizes when disk is bigger than twice the memory", func() {
				totalMemInMb := uint64(1024)

				diskSizeInMb := totalMemInMb*2 + 64
				expectedSwap := totalMemInMb
				collector.MemStats.Total = totalMemInMb * uint64(1024*1024)

				fakePartitioner := diskManager.FakePartitioner
				fakePartitioner.GetDeviceSizeInMbSizes = map[string]uint64{
					"/dev/hda": diskSizeInMb,
				}

				err := platform.SetupEphemeralDiskWithPath("/dev/hda")

				Expect(err).NotTo(HaveOccurred())
				expectedPartitions := []boshdisk.Partition{
					{SizeInMb: expectedSwap, Type: boshdisk.PartitionTypeSwap},
					{SizeInMb: diskSizeInMb - expectedSwap, Type: boshdisk.PartitionTypeLinux},
				}
				Expect(expectedPartitions).To(Equal(fakePartitioner.PartitionPartitions))
			})

			It("calculates ephemeral disk partition sizes when disk twice the memory or smaller", func() {
				totalMemInMb := uint64(1024)

				diskSizeInMb := totalMemInMb*2 - 64
				expectedSwap := diskSizeInMb / 2

				collector.MemStats.Total = totalMemInMb * uint64(1024*1024)

				fakePartitioner := diskManager.FakePartitioner
				fakePartitioner.GetDeviceSizeInMbSizes = map[string]uint64{
					"/dev/hda": diskSizeInMb,
				}

				err := platform.SetupEphemeralDiskWithPath("/dev/hda")

				Expect(err).NotTo(HaveOccurred())
				expectedPartitions := []boshdisk.Partition{
					{SizeInMb: expectedSwap, Type: boshdisk.PartitionTypeSwap},
					{SizeInMb: diskSizeInMb - expectedSwap, Type: boshdisk.PartitionTypeLinux},
				}
				Expect(expectedPartitions).To(Equal(fakePartitioner.PartitionPartitions))
			})

		})
		Describe("SetupTmpDir", func() {
			It("sets up tmp dir", func() {
				err := platform.SetupTmpDir()
				Expect(err).NotTo(HaveOccurred())

				Expect(len(cmdRunner.RunCommands)).To(Equal(2))

				Expect(cmdRunner.RunCommands[0]).To(Equal([]string{"chown", "root:vcap", "/tmp"}))
				Expect(cmdRunner.RunCommands[1]).To(Equal([]string{"chmod", "0770", "/tmp"}))
			})

		})

		Describe("UnmountPersistentDisk", func() {
			Context("when not mounted", func() {
				It("does not unmount persistent disk", func() {
					fakeMounter := diskManager.FakeMounter
					fakeMounter.UnmountDidUnmount = false

					fs.WriteFile("/dev/vdx", []byte{})

					didUnmount, err := platform.UnmountPersistentDisk("/dev/sdx")
					Expect(err).NotTo(HaveOccurred())
					Expect(false).To(Equal(didUnmount))
					Expect(fakeMounter.UnmountPartitionPath).To(Equal("/dev/vdx1"))
				})
			})

			Context("when already mounted", func() {
				It("unmounts persistent disk", func() {
					fakeMounter := diskManager.FakeMounter
					fakeMounter.UnmountDidUnmount = true

					fs.WriteFile("/dev/vdx", []byte{})

					didUnmount, err := platform.UnmountPersistentDisk("/dev/sdx")
					Expect(err).NotTo(HaveOccurred())
					Expect(true).To(Equal(didUnmount))
					Expect(fakeMounter.UnmountPartitionPath).To(Equal("/dev/vdx1"))
				})
			})
		})

		Describe("GetFileContentsFromCDROM", func() {
			It("delegates to cdutil", func() {
				cdutil.GetFileContentsContents = []byte("fake-contents")
				filename := "fake-env"
				contents, err := platform.GetFileContentsFromCDROM(filename)
				Expect(err).NotTo(HaveOccurred())
				Expect(cdutil.GetFileContentsFilename).To(Equal(filename))
				Expect(contents).To(Equal(cdutil.GetFileContentsContents))
			})
		})

		Describe("NormalizeDiskPath", func() {
			It("normalize disk path", func() {
				fs.WriteFile("/dev/xvda", []byte{})
				path, found := platform.NormalizeDiskPath("/dev/sda")

				Expect("/dev/xvda").To(Equal(path))
				Expect(found).To(BeTrue())

				fs.RemoveAll("/dev/xvda")
				fs.WriteFile("/dev/vda", []byte{})
				path, found = platform.NormalizeDiskPath("/dev/sda")

				Expect("/dev/vda").To(Equal(path))
				Expect(found).To(BeTrue())

				fs.RemoveAll("/dev/vda")
				fs.WriteFile("/dev/sda", []byte{})
				path, found = platform.NormalizeDiskPath("/dev/sda")

				Expect("/dev/sda").To(Equal(path))
				Expect(found).To(BeTrue())
			})

			It("get real device path with multiple possible devices", func() {
				fs.WriteFile("/dev/xvda", []byte{})
				fs.WriteFile("/dev/vda", []byte{})

				realPath, found := platform.NormalizeDiskPath("/dev/sda")
				Expect(found).To(BeTrue())
				Expect(realPath).To(Equal("/dev/xvda"))
			})

			Context("within timeout", func() {
				BeforeEach(func() {
					diskWaitTimeout = 1 * time.Second
				})

				It("get real device path with delay", func() {
					time.AfterFunc(time.Second, func() {
						fs.WriteFile("/dev/xvda", []byte{})
					})

					realPath, found := platform.NormalizeDiskPath("/dev/sda")
					Expect(found).To(BeTrue())
					Expect(realPath).To(Equal("/dev/xvda"))
				})
			})

			It("get real device path with delay beyond timeout", func() {
				time.AfterFunc(2*time.Second, func() {
					fs.WriteFile("/dev/xvda", []byte{})
				})

				_, found := platform.NormalizeDiskPath("/dev/sda")
				Expect(found).To(BeFalse())
			})
		})

		Describe("MigratePersistentDisk", func() {
			It("migrate persistent disk", func() {
				fakeMounter := diskManager.FakeMounter

				platform.MigratePersistentDisk("/from/path", "/to/path")

				Expect("/from/path").To(Equal(fakeMounter.RemountAsReadonlyPath))

				Expect(len(cmdRunner.RunCommands)).To(Equal(1))
				Expect(cmdRunner.RunCommands[0]).To(Equal([]string{"sh", "-c", "(tar -C /from/path -cf - .) | (tar -C /to/path -xpf -)"}))

				Expect("/from/path").To(Equal(fakeMounter.UnmountPartitionPath))
				Expect("/to/path").To(Equal(fakeMounter.RemountFromMountPoint))
				Expect("/from/path").To(Equal(fakeMounter.RemountToMountPoint))
			})
		})

		Describe("IsDevicePathMounted", func() {
			It("is device path mounted", func() {
				fs.WriteFile("/dev/xvda", []byte{})
				fakeMounter := diskManager.FakeMounter
				fakeMounter.IsMountedResult = true

				result, err := platform.IsDevicePathMounted("/dev/sda")
				Expect(err).NotTo(HaveOccurred())
				Expect(result).To(BeTrue())
				Expect("/dev/xvda1").To(Equal(fakeMounter.IsMountedDevicePathOrMountPoint))
			})
		})

		Describe("StartMonit", func() {
			It("start monit", func() {
				err := platform.StartMonit()
				Expect(err).NotTo(HaveOccurred())
				Expect(len(cmdRunner.RunCommands)).To(Equal(1))
				Expect(cmdRunner.RunCommands[0]).To(Equal([]string{"sv", "up", "monit"}))
			})
		})

		Describe("SetupMonitUser", func() {
			It("setup monit user if file does not exist", func() {
				err := platform.SetupMonitUser()
				Expect(err).NotTo(HaveOccurred())

				monitUserFileStats := fs.GetFileTestStat("/fake-dir/monit/monit.user")
				Expect(monitUserFileStats).ToNot(BeNil())
				Expect(monitUserFileStats.StringContents()).To(Equal("vcap:random-password"))
			})

			It("setup monit user if file does exist", func() {
				fs.WriteFileString("/fake-dir/monit/monit.user", "vcap:other-random-password")

				err := platform.SetupMonitUser()
				Expect(err).NotTo(HaveOccurred())

				monitUserFileStats := fs.GetFileTestStat("/fake-dir/monit/monit.user")
				Expect(monitUserFileStats).ToNot(BeNil())
				Expect(monitUserFileStats.StringContents()).To(Equal("vcap:other-random-password"))
			})
		})

		Describe("GetMonitCredentials", func() {
			It("get monit credentials reads monit file from disk", func() {
				fs.WriteFileString("/fake-dir/monit/monit.user", "fake-user:fake-random-password")

				username, password, err := platform.GetMonitCredentials()
				Expect(err).NotTo(HaveOccurred())

				Expect(username).To(Equal("fake-user"))
				Expect(password).To(Equal("fake-random-password"))
			})

			It("get monit credentials errs when invalid file format", func() {
				fs.WriteFileString("/fake-dir/monit/monit.user", "fake-user")

				_, _, err := platform.GetMonitCredentials()
				Expect(err).To(HaveOccurred())
			})

			It("get monit credentials leaves colons in password intact", func() {
				fs.WriteFileString("/fake-dir/monit/monit.user", "fake-user:fake:random:password")

				username, password, err := platform.GetMonitCredentials()
				Expect(err).NotTo(HaveOccurred())

				Expect(username).To(Equal("fake-user"))
				Expect(password).To(Equal("fake:random:password"))
			})
		})
	})
})
