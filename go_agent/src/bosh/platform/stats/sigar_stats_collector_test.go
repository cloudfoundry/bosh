package stats_test

import (
	"time"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	. "bosh/platform/stats"
	sigar "github.com/cloudfoundry/gosigar"
	fakesigar "github.com/cloudfoundry/gosigar/fakes"
)

var _ = Describe("sigarStatsCollector", func() {
	var (
		collector StatsCollector
		fakeSigar *fakesigar.FakeSigar
		doneCh    chan struct{}
	)

	BeforeEach(func() {
		fakeSigar = fakesigar.NewFakeSigar()
		collector = NewSigarStatsCollector(fakeSigar)
		doneCh = make(chan struct{})
	})

	Describe("GetCPULoad", func() {
		It("returns cpu load", func() {
			fakeSigar.LoadAverage = sigar.LoadAverage{
				One:     1,
				Five:    5,
				Fifteen: 15,
			}

			load, err := collector.GetCPULoad()

			Expect(err).ToNot(HaveOccurred())
			Expect(load.One).To(Equal(float64(1)))
			Expect(load.Five).To(Equal(float64(5)))
			Expect(load.Fifteen).To(Equal(float64(15)))
		})
	})

	Describe("StartCollecting", func() {
		It("updates cpu stats", func() {
			fakeSigar.CollectCpuStatsCpuCh <- sigar.Cpu{
				User: 10,
				Nice: 20,
				Sys:  30,
				Wait: 40,
			}

			latestGotUpdated := make(chan struct{})

			go collector.StartCollecting(1*time.Millisecond, latestGotUpdated)
			<-latestGotUpdated

			stats, _ := collector.GetCPUStats()
			Expect(stats).To(Equal(CPUStats{
				User:  uint64(10),
				Nice:  uint64(20),
				Sys:   uint64(30),
				Wait:  uint64(40),
				Total: uint64(100),
			}))

			fakeSigar.CollectCpuStatsCpuCh <- sigar.Cpu{
				User: 100,
				Nice: 200,
				Sys:  300,
				Wait: 400,
			}

			<-latestGotUpdated

			stats, _ = collector.GetCPUStats()
			Expect(stats).To(Equal(CPUStats{
				User:  uint64(100),
				Nice:  uint64(200),
				Sys:   uint64(300),
				Wait:  uint64(400),
				Total: uint64(1000),
			}))

			fakeSigar.CollectCpuStatsStopCh <- struct{}{}
		})
	})

	Describe("GetMemStats", func() {
		It("returns mem stats", func() {
			fakeSigar.Mem = sigar.Mem{
				Total:      100,
				ActualUsed: 80,
			}

			stats, err := collector.GetMemStats()

			Expect(err).ToNot(HaveOccurred())
			Expect(stats.Total).To(Equal(uint64(100)))
			Expect(stats.Used).To(Equal(uint64(80)))
		})
	})

	Describe("GetSwapStats", func() {
		It("returns swap stats", func() {
			fakeSigar.Swap = sigar.Swap{
				Total: 100,
				Used:  80,
			}

			stats, err := collector.GetSwapStats()
			Expect(err).ToNot(HaveOccurred())

			Expect(stats.Total).To(Equal(uint64(100)))
			Expect(stats.Used).To(Equal(uint64(80)))
		})
	})

	Describe("GetDiskStats", func() {
		It("returns disk stats", func() {
			fakeSigar.FileSystemUsage = sigar.FileSystemUsage{
				Total:     100,
				Used:      80,
				Files:     1200,
				FreeFiles: 800,
			}

			stats, err := collector.GetDiskStats("/fake-mount-path")
			Expect(err).ToNot(HaveOccurred())

			Expect(fakeSigar.FileSystemUsagePath).To(Equal("/fake-mount-path"))

			Expect(stats.DiskUsage.Total).To(Equal(uint64(100)))
			Expect(stats.DiskUsage.Used).To(Equal(uint64(80)))
			Expect(stats.InodeUsage.Total).To(Equal(uint64(1200)))
			Expect(stats.InodeUsage.Used).To(Equal(uint64(400)))
		})
	})
})
