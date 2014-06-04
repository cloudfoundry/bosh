package stats_test

import (
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

	Describe("GetCPUStats", func() {
		It("returns cpu stats", func() {
			stats, err := collector.GetCPUStats()
			Expect(err).ToNot(HaveOccurred())
			Expect(stats.User > 0).To(BeTrue())
			Expect(stats.Sys > 0).To(BeTrue())
			Expect(stats.Total > 0).To(BeTrue())
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

			Expect(stats.DiskUsage.Total > 0).To(BeTrue())
			Expect(stats.DiskUsage.Used > 0).To(BeTrue())
			Expect(stats.InodeUsage.Total > 0).To(BeTrue())
			Expect(stats.InodeUsage.Used > 0).To(BeTrue())
		})
	})
})
