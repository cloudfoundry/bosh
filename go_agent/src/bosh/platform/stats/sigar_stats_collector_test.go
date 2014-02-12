package stats_test

import (
	. "bosh/platform/stats"
	. "github.com/onsi/ginkgo"
	"github.com/stretchr/testify/assert"
)

func init() {
	Describe("Testing with Ginkgo", func() {
		It("ubuntu get cpu load", func() {

			collector := NewSigarStatsCollector()

			load, err := collector.GetCpuLoad()
			assert.NoError(GinkgoT(), err)
			assert.True(GinkgoT(), load.One >= 0)
			assert.True(GinkgoT(), load.Five >= 0)
			assert.True(GinkgoT(), load.Fifteen >= 0)
		})
		It("ubuntu get cpu stats", func() {

			collector := NewSigarStatsCollector()

			stats, err := collector.GetCpuStats()
			assert.NoError(GinkgoT(), err)
			assert.True(GinkgoT(), stats.User > 0)
			assert.True(GinkgoT(), stats.Sys > 0)
			assert.True(GinkgoT(), stats.Total > 0)
		})
		It("ubuntu get mem stats", func() {

			collector := NewSigarStatsCollector()

			stats, err := collector.GetMemStats()
			assert.NoError(GinkgoT(), err)
			assert.True(GinkgoT(), stats.Total > 0)
			assert.True(GinkgoT(), stats.Used > 0)
		})
		It("ubuntu get swap stats", func() {

			collector := NewSigarStatsCollector()

			stats, err := collector.GetSwapStats()
			assert.NoError(GinkgoT(), err)
			assert.True(GinkgoT(), stats.Total > 0)
		})
		It("ubuntu get disk stats", func() {

			collector := NewSigarStatsCollector()

			stats, err := collector.GetDiskStats("/")
			assert.NoError(GinkgoT(), err)

			assert.True(GinkgoT(), stats.DiskUsage.Total > 0)
			assert.True(GinkgoT(), stats.DiskUsage.Used > 0)
			assert.True(GinkgoT(), stats.InodeUsage.Total > 0)
			assert.True(GinkgoT(), stats.InodeUsage.Used > 0)
		})
	})
}
