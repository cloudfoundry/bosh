package stats

type dummyStatsCollector struct {
}

func NewDummyStatsCollector() (collector StatsCollector) {
	return dummyStatsCollector{}
}

func (p dummyStatsCollector) GetCpuLoad() (load CpuLoad, err error) {
	return
}

func (p dummyStatsCollector) GetCpuStats() (stats CpuStats, err error) {
	stats.Total = 1
	return
}

func (p dummyStatsCollector) GetMemStats() (stats MemStats, err error) {
	stats.Total = 1
	return
}

func (p dummyStatsCollector) GetSwapStats() (stats MemStats, err error) {
	stats.Total = 1
	return
}

func (p dummyStatsCollector) GetDiskStats(devicePath string) (stats DiskStats, err error) {
	stats.Total = 1
	stats.InodeTotal = 1
	return
}
