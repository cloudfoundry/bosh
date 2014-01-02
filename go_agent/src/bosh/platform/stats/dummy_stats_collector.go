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

func (p dummyStatsCollector) GetMemStats() (usage Usage, err error) {
	usage.Total = 1
	return
}

func (p dummyStatsCollector) GetSwapStats() (usage Usage, err error) {
	usage.Total = 1
	return
}

func (p dummyStatsCollector) GetDiskStats(devicePath string) (stats DiskStats, err error) {
	stats.DiskUsage.Total = 1
	stats.InodeUsage.Total = 1
	return
}
