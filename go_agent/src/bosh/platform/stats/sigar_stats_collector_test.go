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
			load, err := collector.GetCPULoad()
			Expect(err).ToNot(HaveOccurred())
			Expect(load.One >= 0).To(BeTrue())
			Expect(load.Five >= 0).To(BeTrue())
			Expect(load.Fifteen >= 0).To(BeTrue())
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
			stats, err := collector.GetMemStats()
			Expect(err).ToNot(HaveOccurred())
			Expect(stats.Total > 0).To(BeTrue())
			Expect(stats.Used > 0).To(BeTrue())
		})
	})

	Describe("GetSwapStats", func() {
		It("returns swap stats", func() {
			stats, err := collector.GetSwapStats()
			Expect(err).ToNot(HaveOccurred())
			Expect(stats.Total > 0).To(BeTrue())
		})
	})

	Describe("GetDiskStats", func() {
		It("returns disk stats", func() {
			stats, err := collector.GetDiskStats("/")
			Expect(err).ToNot(HaveOccurred())

			Expect(stats.DiskUsage.Total).ToNot(BeZero())
			Expect(stats.DiskUsage.Used).ToNot(BeZero())
			Expect(stats.InodeUsage.Total).ToNot(BeZero())
			Expect(stats.InodeUsage.Used).ToNot(BeZero())
		})
	})
})
