package stats_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	. "bosh/platform/stats"
)

func init() {
	Describe("Testing with Ginkgo", func() {
		It("ubuntu get cpu load", func() {

			collector := NewSigarStatsCollector()

			load, err := collector.GetCpuLoad()
			Expect(err).ToNot(HaveOccurred())
			Expect(load.One >= 0).To(BeTrue())
			Expect(load.Five >= 0).To(BeTrue())
			Expect(load.Fifteen >= 0).To(BeTrue())
		})
		It("ubuntu get cpu stats", func() {

			collector := NewSigarStatsCollector()

			stats, err := collector.GetCpuStats()
			Expect(err).ToNot(HaveOccurred())
			Expect(stats.User > 0).To(BeTrue())
			Expect(stats.Sys > 0).To(BeTrue())
			Expect(stats.Total > 0).To(BeTrue())
		})
		It("ubuntu get mem stats", func() {

			collector := NewSigarStatsCollector()

			stats, err := collector.GetMemStats()
			Expect(err).ToNot(HaveOccurred())
			Expect(stats.Total > 0).To(BeTrue())
			Expect(stats.Used > 0).To(BeTrue())
		})
		It("ubuntu get swap stats", func() {

			collector := NewSigarStatsCollector()

			stats, err := collector.GetSwapStats()
			Expect(err).ToNot(HaveOccurred())
			Expect(stats.Total > 0).To(BeTrue())
		})
		It("ubuntu get disk stats", func() {

			collector := NewSigarStatsCollector()

			stats, err := collector.GetDiskStats("/")
			Expect(err).ToNot(HaveOccurred())

			Expect(stats.DiskUsage.Total > 0).To(BeTrue())
			Expect(stats.DiskUsage.Used > 0).To(BeTrue())
			Expect(stats.InodeUsage.Total > 0).To(BeTrue())
			Expect(stats.InodeUsage.Used > 0).To(BeTrue())
		})
	})
}
