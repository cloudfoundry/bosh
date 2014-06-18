package stats_test

import (
	"time"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	. "bosh/platform/stats"
)

var _ = Describe("sigarStatsCollector", func() {
	var (
		collector StatsCollector
	)

	BeforeEach(func() {
		collector = NewSigarStatsCollector()
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
			collector.StartCollecting(100 * time.Millisecond)
			time.Sleep(1 * time.Second)

			stats, err := collector.GetCPUStats()
			Expect(err).ToNot(HaveOccurred())

			Expect(stats.User).ToNot(BeZero())
			Expect(stats.Sys).ToNot(BeZero())
			Expect(stats.Total).ToNot(BeZero())
		})
	})

	Describe("GetCPUStats", func() {
		It("gets delta cpu stats if it is collecting", func() {
			collector.StartCollecting(10 * time.Millisecond)

			time.Sleep(5 * time.Millisecond)
			initialStats, err := collector.GetCPUStats()
			Expect(err).ToNot(HaveOccurred())

			// First iteration will return total cpu stats, so we wait > 2*duration
			time.Sleep(15 * time.Millisecond)
			currentStats, err := collector.GetCPUStats()
			Expect(err).ToNot(HaveOccurred())

			// The next iteration will return the deltas instead of cpu
			Expect(currentStats.User).To(BeNumerically("<", initialStats.User))
			Expect(currentStats.Sys).To(BeNumerically("<", initialStats.Sys))
			Expect(currentStats.Total).To(BeNumerically("<", initialStats.Total))
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
