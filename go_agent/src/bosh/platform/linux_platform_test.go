package platform_test

import (
	"errors"
	"os"
	"path/filepath"
	"time"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	fakedpresolv "bosh/infrastructure/devicepathresolver/fakes"
	boshlog "bosh/logger"
	. "bosh/platform"
	fakecd "bosh/platform/cdutil/fakes"
	boshcmd "bosh/platform/commands"
	boshdisk "bosh/platform/disk"
	fakedisk "bosh/platform/disk/fakes"
	fakenet "bosh/platform/net/fakes"
	fakestats "bosh/platform/stats/fakes"
	boshvitals "bosh/platform/vitals"
	boshsettings "bosh/settings"
	boshdirs "bosh/settings/directories"
	fakesys "bosh/system/fakes"
)

var _ = Describe("LinuxPlatform", func() {
	var (
		collector          *fakestats.FakeStatsCollector
		fs                 *fakesys.FakeFileSystem
		cmdRunner          *fakesys.FakeCmdRunner
		diskManager        *fakedisk.FakeDiskManager
		dirProvider        boshdirs.DirectoriesProvider
		devicePathResolver *fakedpresolv.FakeDevicePathResolver
		platform           Platform
		cdutil             *fakecd.FakeCdUtil
		compressor         boshcmd.Compressor
		copier             boshcmd.Copier
		vitalsService      boshvitals.Service
		netManager         *fakenet.FakeNetManager
		options            LinuxOptions
	)

	BeforeEach(func() {
		logger := boshlog.NewLogger(boshlog.LevelNone)

		collector = &fakestats.FakeStatsCollector{}
		fs = fakesys.NewFakeFileSystem()
		cmdRunner = fakesys.NewFakeCmdRunner()
		diskManager = fakedisk.NewFakeDiskManager()
		dirProvider = boshdirs.NewDirectoriesProvider("/fake-dir")
		cdutil = fakecd.NewFakeCdUtil()
		compressor = boshcmd.NewTarballCompressor(cmdRunner, fs)
		copier = boshcmd.NewCpCopier(cmdRunner, fs, logger)
		vitalsService = boshvitals.NewService(collector, dirProvider)
		netManager = &fakenet.FakeNetManager{}
		devicePathResolver = fakedpresolv.NewFakeDevicePathResolver()
		options = LinuxOptions{}

		fs.SetGlob("/sys/bus/scsi/devices/*:0:0:0/block/*", []string{
			"/sys/bus/scsi/devices/0:0:0:0/block/sr0",
			"/sys/bus/scsi/devices/6:0:0:0/block/sdd",
			"/sys/bus/scsi/devices/fake-host-id:0:0:0/block/sda",
		})

		fs.SetGlob("/sys/bus/scsi/devices/fake-host-id:0:fake-disk-id:0/block/*", []string{
			"/sys/bus/scsi/devices/fake-host-id:0:fake-disk-id:0/block/sdf",
		})
	})

	JustBeforeEach(func() {
		logger := boshlog.NewLogger(boshlog.LevelNone)

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
			5*time.Millisecond,
			options,
			logger,
		)

		platform.SetDevicePathResolver(devicePathResolver)
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
		const expectedEtcHosts = `127.0.0.1 localhost foobar.local

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
			Expect(hostsFileContent).To(Equal(expectedEtcHosts))
		})

	})

	Describe("SetupLogrotate", func() {
		const expectedEtcLogrotate = `# Generated by bosh-agent

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
			Expect(logrotateFileContent).To(Equal(expectedEtcLogrotate))
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
		Context("when ephemeral disk path is provided", func() {
			act := func() error { return platform.SetupEphemeralDiskWithPath("/dev/xvda") }

			It("sets up ephemeral disk with path", func() {
				err := act()
				Expect(err).NotTo(HaveOccurred())

				dataDir := fs.GetFileTestStat("/fake-dir/data")
				Expect(dataDir.FileType).To(Equal(fakesys.FakeFileTypeDir))
				Expect(dataDir.FileMode).To(Equal(os.FileMode(0750)))
			})

			It("returns error if creating data dir fails", func() {
				fs.MkdirAllError = errors.New("fake-mkdir-all-err")

				err := act()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("fake-mkdir-all-err"))
			})

			It("partitions ephemeral disk into swap and data", func() {
				fakePartitioner := diskManager.FakePartitioner

				err := act()
				Expect(err).NotTo(HaveOccurred())

				Expect(fakePartitioner.PartitionDevicePath).To(Equal("/dev/xvda"))
				Expect(len(fakePartitioner.PartitionPartitions)).To(Equal(2))

				swapPartition := fakePartitioner.PartitionPartitions[0]
				ext4Partition := fakePartitioner.PartitionPartitions[1]

				Expect(swapPartition.Type).To(Equal(boshdisk.PartitionTypeSwap))
				Expect(ext4Partition.Type).To(Equal(boshdisk.PartitionTypeLinux))
			})

			It("formats swap and data partitions", func() {
				fakeFormatter := diskManager.FakeFormatter

				err := act()
				Expect(err).NotTo(HaveOccurred())

				Expect(len(fakeFormatter.FormatPartitionPaths)).To(Equal(2))
				Expect(fakeFormatter.FormatPartitionPaths[0]).To(Equal("/dev/xvda1"))
				Expect(fakeFormatter.FormatPartitionPaths[1]).To(Equal("/dev/xvda2"))

				Expect(len(fakeFormatter.FormatFsTypes)).To(Equal(2))
				Expect(fakeFormatter.FormatFsTypes[0]).To(Equal(boshdisk.FileSystemSwap))
				Expect(fakeFormatter.FormatFsTypes[1]).To(Equal(boshdisk.FileSystemExt4))
			})

			It("mounts swap and data partitions", func() {
				fakeMounter := diskManager.FakeMounter

				err := act()
				Expect(err).NotTo(HaveOccurred())

				Expect(len(fakeMounter.MountMountPoints)).To(Equal(1))
				Expect(fakeMounter.MountMountPoints[0]).To(Equal("/fake-dir/data"))
				Expect(len(fakeMounter.MountPartitionPaths)).To(Equal(1))
				Expect(fakeMounter.MountPartitionPaths[0]).To(Equal("/dev/xvda2"))

				Expect(len(fakeMounter.SwapOnPartitionPaths)).To(Equal(1))
				Expect(fakeMounter.SwapOnPartitionPaths[0]).To(Equal("/dev/xvda1"))
			})

			It("calculates ephemeral disk partition sizes when disk is bigger than twice the memory", func() {
				totalMemInMb := uint64(1024)
				diskSizeInMb := totalMemInMb*2 + 64
				expectedSwap := totalMemInMb

				collector.MemStats.Total = totalMemInMb * uint64(1024*1024)

				fakePartitioner := diskManager.FakePartitioner
				fakePartitioner.GetDeviceSizeInMbSizes = map[string]uint64{
					"/dev/xvda": diskSizeInMb,
				}

				err := act()
				Expect(err).NotTo(HaveOccurred())

				Expect(fakePartitioner.PartitionPartitions).To(Equal([]boshdisk.Partition{
					{SizeInMb: expectedSwap, Type: boshdisk.PartitionTypeSwap},
					{SizeInMb: diskSizeInMb - expectedSwap, Type: boshdisk.PartitionTypeLinux},
				}))
			})

			It("calculates ephemeral disk partition sizes when disk twice the memory or smaller", func() {
				totalMemInMb := uint64(1024)
				diskSizeInMb := totalMemInMb*2 - 64
				expectedSwap := diskSizeInMb / 2

				collector.MemStats.Total = totalMemInMb * uint64(1024*1024)

				fakePartitioner := diskManager.FakePartitioner
				fakePartitioner.GetDeviceSizeInMbSizes = map[string]uint64{
					"/dev/xvda": diskSizeInMb,
				}

				err := act()
				Expect(err).NotTo(HaveOccurred())

				Expect(fakePartitioner.PartitionPartitions).To(Equal([]boshdisk.Partition{
					{SizeInMb: expectedSwap, Type: boshdisk.PartitionTypeSwap},
					{SizeInMb: diskSizeInMb - expectedSwap, Type: boshdisk.PartitionTypeLinux},
				}))
			})
		})

		Context("when ephemeral disk path is not provided", func() {
			act := func() error { return platform.SetupEphemeralDiskWithPath("") }

			It("creates data directory on a root partition (without swap)", func() {
				err := act()
				Expect(err).NotTo(HaveOccurred())

				dataDir := fs.GetFileTestStat("/fake-dir/data")
				Expect(dataDir.FileType).To(Equal(fakesys.FakeFileTypeDir))
				Expect(dataDir.FileMode).To(Equal(os.FileMode(0750)))
			})

			It("returns error if creating data dir fails", func() {
				fs.MkdirAllError = errors.New("fake-mkdir-all-err")

				err := act()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("fake-mkdir-all-err"))
			})

			It("does not try to partition anything", func() {
				err := act()
				Expect(err).NotTo(HaveOccurred())
				Expect(len(diskManager.FakePartitioner.PartitionPartitions)).To(Equal(0))
			})

			It("does not try to format anything", func() {
				err := act()
				Expect(err).NotTo(HaveOccurred())
				Expect(len(diskManager.FakeFormatter.FormatPartitionPaths)).To(Equal(0))
			})

			It("does not try to mount anything", func() {
				err := act()
				Expect(err).NotTo(HaveOccurred())
				Expect(len(diskManager.FakeMounter.MountMountPoints)).To(Equal(0))
			})
		})
	})

	Describe("SetupDataDir", func() {
		It("creates sys/log and sys/run directories in data directory", func() {
			err := platform.SetupDataDir()
			Expect(err).NotTo(HaveOccurred())

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
	})

	Describe("SetupTmpDir", func() {
		act := func() error { return platform.SetupTmpDir() }

		It("changes permissions on /tmp", func() {
			err := act()
			Expect(err).NotTo(HaveOccurred())

			Expect(cmdRunner.RunCommands[0]).To(Equal([]string{"chown", "root:vcap", "/tmp"}))
			Expect(cmdRunner.RunCommands[1]).To(Equal([]string{"chmod", "0770", "/tmp"}))
			Expect(cmdRunner.RunCommands[2]).To(Equal([]string{"chmod", "0700", "/var/tmp"}))
		})

		It("creates new temp dir", func() {
			err := act()
			Expect(err).NotTo(HaveOccurred())

			fileStats := fs.GetFileTestStat("/fake-dir/data/tmp")
			Expect(fileStats).NotTo(BeNil())
			Expect(fileStats.FileType).To(Equal(fakesys.FakeFileType(fakesys.FakeFileTypeDir)))
			Expect(fileStats.FileMode).To(Equal(os.FileMode(0755)))
		})

		It("returns error if creating new temp dir errs", func() {
			fs.MkdirAllError = errors.New("fake-mkdir-error")

			err := act()
			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(ContainSubstring("fake-mkdir-error"))
		})

		It("sets TMPDIR environment variable so that children of this process will use new temp dir", func() {
			err := act()
			Expect(err).NotTo(HaveOccurred())
			Expect(os.Getenv("TMPDIR")).To(Equal("/fake-dir/data/tmp"))
		})

		It("returns error if setting TMPDIR errs", func() {
			// uses os package; no way to trigger err
		})

		ItDoesNotTryToUseLoopDevice := func() {
			It("does not create new tmp filesystem", func() {
				act()
				for _, cmd := range cmdRunner.RunCommands {
					Expect(cmd[0]).ToNot(Equal("truncate"))
					Expect(cmd[0]).ToNot(Equal("mke2fs"))
				}
			})

			It("does not try to mount anything /tmp", func() {
				act()
				Expect(len(diskManager.FakeMounter.MountPartitionPaths)).To(Equal(0))
			})
		}

		Context("when UseDefaultTmpDir option is set to false", func() {
			BeforeEach(func() {
				options.UseDefaultTmpDir = false
			})

			Context("when /tmp is not a mount point", func() {
				BeforeEach(func() {
					diskManager.FakeMounter.IsMountPointResult = false
				})

				It("creates new tmp filesystem of 128MB placed in data dir", func() {
					err := act()
					Expect(err).NotTo(HaveOccurred())

					Expect(cmdRunner.RunCommands[3]).To(Equal([]string{"truncate", "-s", "128M", "/fake-dir/data/root_tmp"}))
					Expect(cmdRunner.RunCommands[4]).To(Equal([]string{"chmod", "0700", "/fake-dir/data/root_tmp"}))
					Expect(cmdRunner.RunCommands[5]).To(Equal([]string{"mke2fs", "-t", "ext4", "-m", "1", "-F", "/fake-dir/data/root_tmp"}))
				})

				It("mounts the new tmp filesystem over /tmp", func() {
					err := act()
					Expect(err).NotTo(HaveOccurred())

					mounter := diskManager.FakeMounter
					Expect(len(mounter.MountPartitionPaths)).To(Equal(1))
					Expect(mounter.MountPartitionPaths[0]).To(Equal("/fake-dir/data/root_tmp"))
					Expect(mounter.MountMountPoints[0]).To(Equal("/tmp"))
					Expect(mounter.MountMountOptions[0]).To(Equal([]string{"-t", "ext4", "-o", "loop"}))
				})

				It("returns error if mounting the new tmp filesystem fails", func() {
					diskManager.FakeMounter.MountErr = errors.New("fake-mount-error")

					err := act()
					Expect(err).To(HaveOccurred())
					Expect(err.Error()).To(ContainSubstring("fake-mount-error"))
				})

				It("changes permissions on /tmp again because it is a new mount", func() {
					err := act()
					Expect(err).NotTo(HaveOccurred())

					Expect(cmdRunner.RunCommands[6]).To(Equal([]string{"chown", "root:vcap", "/tmp"}))
					Expect(cmdRunner.RunCommands[7]).To(Equal([]string{"chmod", "0770", "/tmp"}))
				})
			})

			Context("when /tmp is a mount point", func() {
				BeforeEach(func() {
					diskManager.FakeMounter.IsMountPointResult = true
				})

				It("returns without an error", func() {
					err := act()
					Expect(err).ToNot(HaveOccurred())
				})

				ItDoesNotTryToUseLoopDevice()
			})

			Context("when /tmp cannot be determined if it is a mount point", func() {
				BeforeEach(func() {
					diskManager.FakeMounter.IsMountPointErr = errors.New("fake-is-mount-point-error")
				})

				It("returns error", func() {
					err := act()
					Expect(err).To(HaveOccurred())
					Expect(err.Error()).To(ContainSubstring("fake-is-mount-point-error"))
				})

				ItDoesNotTryToUseLoopDevice()
			})
		})

		Context("when UseDefaultTmpDir option is set to true", func() {
			BeforeEach(func() {
				options.UseDefaultTmpDir = true
			})

			It("returns without an error", func() {
				err := act()
				Expect(err).ToNot(HaveOccurred())
			})

			ItDoesNotTryToUseLoopDevice()
		})
	})

	Describe("MountPersistentDisk", func() {
		act := func() error { return platform.MountPersistentDisk("fake-volume-id", "/mnt/point") }

		Context("when device path is successfully resolved", func() {
			BeforeEach(func() {
				devicePathResolver.RegisterRealDevicePath("fake-volume-id", "fake-real-device-path")
			})

			Context("when UsePreformattedPersistentDisk set to false", func() {
				It("creates the mount directory with the correct permissions", func() {
					err := act()
					Expect(err).ToNot(HaveOccurred())

					mountPoint := fs.GetFileTestStat("/mnt/point")
					Expect(mountPoint.FileType).To(Equal(fakesys.FakeFileTypeDir))
					Expect(mountPoint.FileMode).To(Equal(os.FileMode(0700)))
				})

				It("returns error when creating mount directory fails", func() {
					fs.MkdirAllError = errors.New("fake-mkdir-all-err")

					err := act()
					Expect(err).To(HaveOccurred())
					Expect(err.Error()).To(ContainSubstring("fake-mkdir-all-err"))
				})

				It("partitions the disk", func() {
					err := act()
					Expect(err).ToNot(HaveOccurred())

					partitions := []boshdisk.Partition{{Type: boshdisk.PartitionTypeLinux}}
					Expect(diskManager.FakePartitioner.PartitionDevicePath).To(Equal("fake-real-device-path"))
					Expect(diskManager.FakePartitioner.PartitionPartitions).To(Equal(partitions))
				})

				It("formats the disk", func() {
					err := act()
					Expect(err).ToNot(HaveOccurred())
					Expect(diskManager.FakeFormatter.FormatPartitionPaths).To(Equal([]string{"fake-real-device-path1"}))
					Expect(diskManager.FakeFormatter.FormatFsTypes).To(Equal([]boshdisk.FileSystemType{boshdisk.FileSystemExt4}))
				})

				It("mounts the disk", func() {
					err := act()
					Expect(err).ToNot(HaveOccurred())
					Expect(diskManager.FakeMounter.MountPartitionPaths).To(Equal([]string{"fake-real-device-path1"}))
					Expect(diskManager.FakeMounter.MountMountPoints).To(Equal([]string{"/mnt/point"}))
					Expect(diskManager.FakeMounter.MountMountOptions).To(Equal([][]string{nil}))
				})
			})

			Context("when UsePreformattedPersistentDisk set to true", func() {
				BeforeEach(func() {
					options.UsePreformattedPersistentDisk = true
				})

				It("creates the mount directory with the correct permissions", func() {
					err := act()
					Expect(err).ToNot(HaveOccurred())

					mountPoint := fs.GetFileTestStat("/mnt/point")
					Expect(mountPoint.FileType).To(Equal(fakesys.FakeFileTypeDir))
					Expect(mountPoint.FileMode).To(Equal(os.FileMode(0700)))
				})

				It("returns error when creating mount directory fails", func() {
					fs.MkdirAllError = errors.New("fake-mkdir-all-err")

					err := act()
					Expect(err).To(HaveOccurred())
					Expect(err.Error()).To(ContainSubstring("fake-mkdir-all-err"))
				})

				It("mounts volume at mount point", func() {
					err := act()
					Expect(err).ToNot(HaveOccurred())

					mounter := diskManager.FakeMounter
					Expect(len(mounter.MountPartitionPaths)).To(Equal(1))
					Expect(mounter.MountPartitionPaths).To(Equal([]string{"fake-real-device-path"})) // no '1' because no partition
					Expect(mounter.MountMountPoints).To(Equal([]string{"/mnt/point"}))
					Expect(mounter.MountMountOptions).To(Equal([][]string{nil}))
				})

				It("returns error when mounting fails", func() {
					diskManager.FakeMounter.MountErr = errors.New("fake-mount-err")

					err := act()
					Expect(err).To(HaveOccurred())
					Expect(err.Error()).To(ContainSubstring("fake-mount-err"))
				})

				It("does not partition the disk", func() {
					err := act()
					Expect(err).ToNot(HaveOccurred())
					Expect(diskManager.FakePartitioner.PartitionCalled).To(BeFalse())
				})

				It("does not format the disk", func() {
					err := act()
					Expect(err).ToNot(HaveOccurred())
					Expect(diskManager.FakeFormatter.FormatCalled).To(BeFalse())
				})
			})
		})

		Context("when device path is not successfully resolved", func() {
			It("return an error", func() {
				devicePathResolver.GetRealDevicePathErr = errors.New("fake-get-real-device-path-err")

				err := act()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("fake-get-real-device-path-err"))
			})
		})
	})

	Describe("UnmountPersistentDisk", func() {
		act := func() (bool, error) { return platform.UnmountPersistentDisk("fake-device-path") }

		Context("when device path can be resolved", func() {
			BeforeEach(func() {
				devicePathResolver.RegisterRealDevicePath("fake-device-path", "fake-real-device-path")
			})

			ItUnmountsPersistentDisk := func(expectedUnmountMountPoint string) {
				It("returs true without an error if unmounting succeeded", func() {
					diskManager.FakeMounter.UnmountDidUnmount = true

					didUnmount, err := act()
					Expect(err).NotTo(HaveOccurred())
					Expect(didUnmount).To(BeTrue())
					Expect(diskManager.FakeMounter.UnmountPartitionPathOrMountPoint).To(Equal(expectedUnmountMountPoint))
				})

				It("returs false without an error if was already unmounted", func() {
					diskManager.FakeMounter.UnmountDidUnmount = false

					didUnmount, err := act()
					Expect(err).NotTo(HaveOccurred())
					Expect(didUnmount).To(BeFalse())
					Expect(diskManager.FakeMounter.UnmountPartitionPathOrMountPoint).To(Equal(expectedUnmountMountPoint))
				})

				It("returns error if unmounting fails", func() {
					diskManager.FakeMounter.UnmountDidUnmount = false
					diskManager.FakeMounter.UnmountErr = errors.New("fake-unmount-err")

					didUnmount, err := act()
					Expect(err).To(HaveOccurred())
					Expect(err.Error()).To(ContainSubstring("fake-unmount-err"))
					Expect(didUnmount).To(BeFalse())
					Expect(diskManager.FakeMounter.UnmountPartitionPathOrMountPoint).To(Equal(expectedUnmountMountPoint))
				})
			}

			Context("UsePreformattedPersistentDisk is set to false", func() {
				ItUnmountsPersistentDisk("fake-real-device-path1") // note partition '1'
			})

			Context("UsePreformattedPersistentDisk is set to true", func() {
				BeforeEach(func() {
					options.UsePreformattedPersistentDisk = true
				})

				ItUnmountsPersistentDisk("fake-real-device-path") // note no '1'; no partitions
			})
		})

		Context("when device path can be resolved", func() {
			BeforeEach(func() {
				devicePathResolver.GetRealDevicePathErr = errors.New("fake-get-real-device-path-err")
			})

			It("returns error", func() {
				didUnmount, err := act()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("fake-get-real-device-path-err"))
				Expect(didUnmount).To(BeFalse())
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
		Context("when real device path was resolved without an error", func() {
			It("returns real device path and true", func() {
				devicePathResolver.RegisterRealDevicePath("fake-device-path", "fake-real-device-path")
				realDevicePath, found := platform.NormalizeDiskPath("fake-device-path")
				Expect(realDevicePath).To(Equal("fake-real-device-path"))
				Expect(found).To(BeTrue())
			})
		})

		Context("when real device path was not resolved without an error", func() {
			It("returns real device path and true", func() {
				devicePathResolver.GetRealDevicePathErr = errors.New("fake-get-real-device-path-err")

				realDevicePath, found := platform.NormalizeDiskPath("fake-device-path")
				Expect(realDevicePath).To(Equal(""))
				Expect(found).To(BeFalse())
			})
		})
	})

	Describe("MigratePersistentDisk", func() {
		It("migrate persistent disk", func() {
			err := platform.MigratePersistentDisk("/from/path", "/to/path")
			Expect(err).ToNot(HaveOccurred())

			fakeMounter := diskManager.FakeMounter
			Expect(fakeMounter.RemountAsReadonlyPath).To(Equal("/from/path"))

			Expect(len(cmdRunner.RunCommands)).To(Equal(1))
			Expect(cmdRunner.RunCommands[0]).To(Equal([]string{"sh", "-c", "(tar -C /from/path -cf - .) | (tar -C /to/path -xpf -)"}))

			Expect(fakeMounter.UnmountPartitionPathOrMountPoint).To(Equal("/from/path"))
			Expect(fakeMounter.RemountFromMountPoint).To(Equal("/to/path"))
			Expect(fakeMounter.RemountToMountPoint).To(Equal("/from/path"))
		})
	})

	Describe("IsPersistentDiskMounted", func() {
		act := func() (bool, error) { return platform.IsPersistentDiskMounted("fake-device-path") }

		Context("when device path can be resolved", func() {
			BeforeEach(func() {
				devicePathResolver.RegisterRealDevicePath("fake-device-path", "fake-real-device-path")
			})

			ItChecksPersistentDiskMountPoint := func(expectedCheckedMountPoint string) {
				Context("when checking persistent disk mount point succeeds", func() {
					It("returns true if mount point exists", func() {
						diskManager.FakeMounter.IsMountedResult = true

						isMounted, err := act()
						Expect(err).NotTo(HaveOccurred())
						Expect(isMounted).To(BeTrue())
						Expect(diskManager.FakeMounter.IsMountedDevicePathOrMountPoint).To(Equal(expectedCheckedMountPoint))
					})

					It("returns false if mount point does not exist", func() {
						diskManager.FakeMounter.IsMountedResult = false

						isMounted, err := act()
						Expect(err).NotTo(HaveOccurred())
						Expect(isMounted).To(BeFalse())
						Expect(diskManager.FakeMounter.IsMountedDevicePathOrMountPoint).To(Equal(expectedCheckedMountPoint))
					})
				})

				Context("checking persistent disk mount points fails", func() {
					It("returns error", func() {
						diskManager.FakeMounter.IsMountedResult = false
						diskManager.FakeMounter.IsMountedErr = errors.New("fake-is-mounted-err")

						isMounted, err := act()
						Expect(err).To(HaveOccurred())
						Expect(err.Error()).To(ContainSubstring("fake-is-mounted-err"))
						Expect(isMounted).To(BeFalse())
						Expect(diskManager.FakeMounter.IsMountedDevicePathOrMountPoint).To(Equal(expectedCheckedMountPoint))
					})
				})
			}

			Context("UsePreformattedPersistentDisk is set to false", func() {
				ItChecksPersistentDiskMountPoint("fake-real-device-path1") // note partition '1'
			})

			Context("UsePreformattedPersistentDisk is set to true", func() {
				BeforeEach(func() {
					options.UsePreformattedPersistentDisk = true
				})

				ItChecksPersistentDiskMountPoint("fake-real-device-path") // note no '1'; no partitions
			})
		})

		Context("when device path can be resolved", func() {
			BeforeEach(func() {
				devicePathResolver.GetRealDevicePathErr = errors.New("fake-get-real-device-path-err")
			})

			It("returns error", func() {
				isMounted, err := act()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("fake-get-real-device-path-err"))
				Expect(isMounted).To(BeFalse())
			})
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

	Describe("PrepareForNetworkingChange", func() {
		It("removes the network persistent rules file", func() {
			fs.WriteFile("/etc/udev/rules.d/70-persistent-net.rules", []byte{})

			err := platform.PrepareForNetworkingChange()
			Expect(err).NotTo(HaveOccurred())

			Expect(fs.FileExists("/etc/udev/rules.d/70-persistent-net.rules")).To(BeFalse())
		})

		It("returns error if removing persistent rules file fails", func() {
			fs.RemoveAllError = errors.New("fake-remove-all-error")

			err := platform.PrepareForNetworkingChange()
			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(ContainSubstring("fake-remove-all-error"))
		})
	})

	Describe("GetDefaultNetwork", func() {
		It("returns default network according to net manager", func() {
			netManager.GetDefaultNetworkNetwork = boshsettings.Network{IP: "fake-ip"}

			network, err := platform.GetDefaultNetwork()
			Expect(err).ToNot(HaveOccurred())
			Expect(network).To(Equal(boshsettings.Network{IP: "fake-ip"}))
		})

		It("returns error if net manager fails to retrieve default network", func() {
			netManager.GetDefaultNetworkErr = errors.New("fake-get-default-network-err")

			network, err := platform.GetDefaultNetwork()
			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(ContainSubstring("fake-get-default-network-err"))
			Expect(network).To(Equal(boshsettings.Network{}))
		})
	})
})
