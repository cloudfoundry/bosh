package agent

import (
	boshmbus "bosh/mbus"
	boshstats "bosh/platform/stats"
	boshsettings "bosh/settings"
	"fmt"
)

const (
	SYSTEM_DISK_PATH     = "/"
	EPHEMERAL_DISK_PATH  = "/var/vcap/data"
	PERSISTENT_DISK_PATH = "/var/vcap/store"
)

func getHeartbeat(settings boshsettings.Settings, collector boshstats.StatsCollector) (hb boshmbus.Heartbeat) {
	hb = updateWithCpuLoad(collector, hb)
	hb = updateWithCpuStats(collector, hb)
	hb = updateWithMemStats(collector, hb)
	hb = updateWithSwapStats(collector, hb)
	hb = updateWithDiskStats(settings, collector, hb)
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

	user := float64(cpuStats.User) / float64(cpuStats.Total) * 100
	sys := float64(cpuStats.Sys) / float64(cpuStats.Total) * 100
	wait := float64(cpuStats.Wait) / float64(cpuStats.Total) * 100

	updatedHb.Vitals.Cpu = boshmbus.CpuStats{
		User: fmt.Sprintf("%.1f", user),
		Sys:  fmt.Sprintf("%.1f", sys),
		Wait: fmt.Sprintf("%.1f", wait),
	}
	return
}

func updateWithMemStats(platform boshstats.StatsCollector, hb boshmbus.Heartbeat) (updatedHb boshmbus.Heartbeat) {
	updatedHb = hb
	memStats, err := platform.GetMemStats()
	if err != nil {
		return
	}

	percent := float64(memStats.Used) / float64(memStats.Total) * 100
	kb := memStats.Used / 1024

	updatedHb.Vitals.UsedMem = boshmbus.MemStats{
		Percent: fmt.Sprintf("%.0f", percent),
		Kb:      fmt.Sprintf("%d", kb),
	}
	return
}

func updateWithSwapStats(platform boshstats.StatsCollector, hb boshmbus.Heartbeat) (updatedHb boshmbus.Heartbeat) {
	updatedHb = hb
	swapStats, err := platform.GetSwapStats()
	if err != nil {
		return
	}

	percent := float64(swapStats.Used) / float64(swapStats.Total) * 100
	kb := swapStats.Used / 1024

	updatedHb.Vitals.UsedSwap = boshmbus.MemStats{
		Percent: fmt.Sprintf("%.0f", percent),
		Kb:      fmt.Sprintf("%d", kb),
	}
	return
}

func updateWithDiskStats(settings boshsettings.Settings, platform boshstats.StatsCollector, hb boshmbus.Heartbeat) (updatedHb boshmbus.Heartbeat) {
	updatedHb = hb

	updatedHb.Vitals.Disks.System = getDiskStats(platform, SYSTEM_DISK_PATH)

	if settings.Disks.Ephemeral != "" {
		updatedHb.Vitals.Disks.Ephemeral = getDiskStats(platform, EPHEMERAL_DISK_PATH)
	}

	if len(settings.Disks.Persistent) == 1 {
		updatedHb.Vitals.Disks.Persistent = getDiskStats(platform, PERSISTENT_DISK_PATH)
	}

	return
}

func getDiskStats(platform boshstats.StatsCollector, devicePath string) (stats boshmbus.DiskStats) {
	diskStats, err := platform.GetDiskStats(devicePath)
	if err != nil {
		return
	}

	percent := float64(diskStats.Used) / float64(diskStats.Total) * 100
	inodePercent := float64(diskStats.InodeUsed) / float64(diskStats.InodeTotal) * 100

	stats.Percent = fmt.Sprintf("%.0f", percent)
	stats.InodePercent = fmt.Sprintf("%.0f", inodePercent)

	return
}
