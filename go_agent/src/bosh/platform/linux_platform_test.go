package platform_test

import (
	. "bosh/platform"
	fakecd "bosh/platform/cdutil/fakes"
	boshcmd "bosh/platform/commands"
	fakedisk "bosh/platform/disk/fakes"
	boshnet "bosh/platform/net"
	fakestats "bosh/platform/stats/fakes"
	boshvitals "bosh/platform/vitals"
	boshdirs "bosh/settings/directories"
	fakesys "bosh/system/fakes"
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
	"time"
)

var _ = Describe("LinuxPlatform", func() {
	Describe("LookupScsiDisk", func() {
		var (
			collector     *fakestats.FakeStatsCollector
			fs            *fakesys.FakeFileSystem
			cmdRunner     *fakesys.FakeCmdRunner
			diskManager   fakedisk.FakeDiskManager
			dirProvider   boshdirs.DirectoriesProvider
			platform      Platform
			cdutil        *fakecd.FakeCdUtil
			compressor    boshcmd.Compressor
			copier        boshcmd.Copier
			vitalsService boshvitals.Service
		)

		const sleepInterval = time.Millisecond * 5

		BeforeEach(func() {
			collector = &fakestats.FakeStatsCollector{}
			fs = fakesys.NewFakeFileSystem()
			cmdRunner = &fakesys.FakeCmdRunner{}
			diskManager = fakedisk.NewFakeDiskManager(cmdRunner)
			dirProvider = boshdirs.NewDirectoriesProvider("/fake-dir")
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
				1*time.Millisecond,
				netManager,
				sleepInterval,
			)
		})

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
})
