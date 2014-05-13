package disk_test

import (
	"time"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	boshlog "bosh/logger"
	. "bosh/platform/disk"
	fakesys "bosh/system/fakes"
)

var _ = Describe("NewLinuxDiskManager", func() {
	var (
		runner *fakesys.FakeCmdRunner
		fs     *fakesys.FakeFileSystem
		logger boshlog.Logger
	)

	BeforeEach(func() {
		runner = fakesys.NewFakeCmdRunner()
		fs = fakesys.NewFakeFileSystem()
		logger = boshlog.NewLogger(boshlog.LevelNone)
	})

	Context("when bindMount is set to false", func() {
		It("returns disk manager configured not to do bind mounting", func() {
			expectedMountsSearcher := NewProcMountsSearcher(fs)
			expectedMounter := NewLinuxMounter(runner, expectedMountsSearcher, 1*time.Second)

			diskManager := NewLinuxDiskManager(logger, runner, fs, false)
			Expect(diskManager.GetMounter()).To(Equal(expectedMounter))
		})
	})

	Context("when bindMount is set to true", func() {
		It("returns disk manager configured to do bind mounting", func() {
			expectedMountsSearcher := NewCmdMountsSearcher(runner)
			expectedMounter := NewLinuxBindMounter(NewLinuxMounter(runner, expectedMountsSearcher, 1*time.Second))

			diskManager := NewLinuxDiskManager(logger, runner, fs, true)
			Expect(diskManager.GetMounter()).To(Equal(expectedMounter))
		})
	})
})
