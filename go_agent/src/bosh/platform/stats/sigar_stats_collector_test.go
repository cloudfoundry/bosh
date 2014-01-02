package stats

import (
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestUbuntuGetCpuLoad(t *testing.T) {
	collector := sigarStatsCollector{}

	load, err := collector.GetCpuLoad()
	assert.NoError(t, err)
	assert.True(t, load.One >= 0)
	assert.True(t, load.Five >= 0)
	assert.True(t, load.Fifteen >= 0)
}

func TestUbuntuGetCpuStats(t *testing.T) {
	collector := sigarStatsCollector{}

	stats, err := collector.GetCpuStats()
	assert.NoError(t, err)
	assert.True(t, stats.User > 0)
	assert.True(t, stats.Sys > 0)
	assert.True(t, stats.Total > 0)
}

func TestUbuntuGetMemStats(t *testing.T) {
	collector := sigarStatsCollector{}

	stats, err := collector.GetMemStats()
	assert.NoError(t, err)
	assert.True(t, stats.Total > 0)
	assert.True(t, stats.Used > 0)
}

func TestUbuntuGetSwapStats(t *testing.T) {
	collector := sigarStatsCollector{}

	stats, err := collector.GetSwapStats()
	assert.NoError(t, err)
	assert.True(t, stats.Total > 0)
}

func TestUbuntuGetDiskStats(t *testing.T) {
	collector := sigarStatsCollector{}

	stats, err := collector.GetDiskStats("/")
	assert.NoError(t, err)

	assert.True(t, stats.DiskUsage.Total > 0)
	assert.True(t, stats.DiskUsage.Used > 0)
	assert.True(t, stats.InodeUsage.Total > 0)
	assert.True(t, stats.InodeUsage.Used > 0)
}
