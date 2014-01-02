package agent

import (
	boshmbus "bosh/mbus"
	boshstats "bosh/platform/stats"
	boshsettings "bosh/settings"
	boshdir "bosh/settings/directories"
	"fmt"
)

const (
	SYSTEM_DISK_PATH = "/"
)

func getHeartbeat(settings boshsettings.Service, collector boshstats.StatsCollector, dirProvider boshdir.DirectoriesProvider) (hb boshmbus.Heartbeat) {
	hb = updateWithCpuLoad(collector, hb)
	hb = updateWithCpuStats(collector, hb)
	hb = updateWithMemStats(collector, hb)
	hb = updateWithSwapStats(collector, hb)
	hb = updateWithDiskStats(settings, collector, hb, dirProvider)
	return
}

func updateWithCpuLoad(platform boshstats.StatsCollector, hb boshmbus.Heartbeat) (updatedHb boshmbus.Heartbeat) {
	updatedHb = hb

	load, err := platform.GetCpuLoad()
	if err != nil {
		return
	}

	one := fmt.Sprintf("%.2f", load.One)
	five := fmt.Sprintf("%.2f", load.Five)
	fifteen := fmt.Sprintf("%.2f", load.Fifteen)

	updatedHb.Vitals.CpuLoad = []string{one, five, fifteen}

	return
}

func updateWithCpuStats(platform boshstats.StatsCollector, hb boshmbus.Heartbeat) (updatedHb boshmbus.Heartbeat) {
	updatedHb = hb
	cpuStats, err := platform.GetCpuStats()
	if err != nil {
		return
	}

	updatedHb.Vitals.Cpu = boshmbus.CpuStats{
		User: cpuStats.UserPercent().FormatFractionOf100(1),
		Sys:  cpuStats.SysPercent().FormatFractionOf100(1),
		Wait: cpuStats.WaitPercent().FormatFractionOf100(1),
	}
	return
}

func updateWithMemStats(platform boshstats.StatsCollector, hb boshmbus.Heartbeat) (updatedHb boshmbus.Heartbeat) {
	updatedHb = hb
	memStats, err := platform.GetMemStats()
	if err != nil {
		return
	}

	updatedHb.Vitals.UsedMem = boshmbus.MemStats{
		Percent: memStats.Percent().FormatFractionOf100(0),
		Kb:      fmt.Sprintf("%d", memStats.Used/1024),
	}
	return
}

func updateWithSwapStats(platform boshstats.StatsCollector, hb boshmbus.Heartbeat) (updatedHb boshmbus.Heartbeat) {
	updatedHb = hb
	swapStats, err := platform.GetSwapStats()
	if err != nil {
		return
	}

	updatedHb.Vitals.UsedSwap = boshmbus.MemStats{
		Percent: swapStats.Percent().FormatFractionOf100(0),
		Kb:      fmt.Sprintf("%d", swapStats.Used/1024),
	}
	return
}

func updateWithDiskStats(settings boshsettings.Service, platform boshstats.StatsCollector, hb boshmbus.Heartbeat, dirProvider boshdir.DirectoriesProvider) (updatedHb boshmbus.Heartbeat) {
	updatedHb = hb

	updatedHb.Vitals.Disks.System = getDiskStats(platform, SYSTEM_DISK_PATH)

	if settings.GetDisks().Ephemeral != "" {
		updatedHb.Vitals.Disks.Ephemeral = getDiskStats(platform, dirProvider.DataDir())
	}

	if len(settings.GetDisks().Persistent) == 1 {
		updatedHb.Vitals.Disks.Persistent = getDiskStats(platform, dirProvider.StoreDir())
	}

	return
}

func getDiskStats(platform boshstats.StatsCollector, devicePath string) (stats boshmbus.DiskStats) {
	diskStats, err := platform.GetDiskStats(devicePath)
	if err != nil {
		return
	}

	stats.Percent = diskStats.DiskUsage.Percent().FormatFractionOf100(0)
	stats.InodePercent = diskStats.InodeUsage.Percent().FormatFractionOf100(0)
	return
}
