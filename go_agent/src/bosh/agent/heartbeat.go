package agent

import (
	"bosh/mbus"
	"bosh/platform"
	"bosh/settings"
	"fmt"
)

const (
	SYSTEM_DISK_PATH     = "/"
	EPHEMERAL_DISK_PATH  = "/var/vcap/data"
	PERSISTENT_DISK_PATH = "/var/vcap/store"
)

func getHeartbeat(s settings.Settings, p platform.Platform) (hb mbus.Heartbeat) {
	hb = updateWithCpuLoad(p, hb)
	hb = updateWithCpuStats(p, hb)
	hb = updateWithMemStats(p, hb)
	hb = updateWithSwapStats(p, hb)
	hb = updateWithDiskStats(s, p, hb)
	return
}

func updateWithCpuLoad(p platform.Platform, hb mbus.Heartbeat) (updatedHb mbus.Heartbeat) {
	updatedHb = hb

	load, err := p.GetCpuLoad()
	if err != nil {
		return
	}

	one := fmt.Sprintf("%.2f", load.One)
	five := fmt.Sprintf("%.2f", load.Five)
	fifteen := fmt.Sprintf("%.2f", load.Fifteen)

	updatedHb.Vitals.CpuLoad = []string{one, five, fifteen}

	return
}

func updateWithCpuStats(p platform.Platform, hb mbus.Heartbeat) (updatedHb mbus.Heartbeat) {
	updatedHb = hb
	cpuStats, err := p.GetCpuStats()
	if err != nil {
		return
	}

	user := float64(cpuStats.User) / float64(cpuStats.Total) * 100
	sys := float64(cpuStats.Sys) / float64(cpuStats.Total) * 100
	wait := float64(cpuStats.Wait) / float64(cpuStats.Total) * 100

	updatedHb.Vitals.Cpu = mbus.CpuStats{
		User: fmt.Sprintf("%.1f", user),
		Sys:  fmt.Sprintf("%.1f", sys),
		Wait: fmt.Sprintf("%.1f", wait),
	}
	return
}

func updateWithMemStats(p platform.Platform, hb mbus.Heartbeat) (updatedHb mbus.Heartbeat) {
	updatedHb = hb
	memStats, err := p.GetMemStats()
	if err != nil {
		return
	}

	percent := float64(memStats.Used) / float64(memStats.Total) * 100
	kb := memStats.Used / 1024

	updatedHb.Vitals.UsedMem = mbus.MemStats{
		Percent: fmt.Sprintf("%.0f", percent),
		Kb:      fmt.Sprintf("%d", kb),
	}
	return
}

func updateWithSwapStats(p platform.Platform, hb mbus.Heartbeat) (updatedHb mbus.Heartbeat) {
	updatedHb = hb
	swapStats, err := p.GetSwapStats()
	if err != nil {
		return
	}

	percent := float64(swapStats.Used) / float64(swapStats.Total) * 100
	kb := swapStats.Used / 1024

	updatedHb.Vitals.UsedSwap = mbus.MemStats{
		Percent: fmt.Sprintf("%.0f", percent),
		Kb:      fmt.Sprintf("%d", kb),
	}
	return
}

func updateWithDiskStats(s settings.Settings, p platform.Platform, hb mbus.Heartbeat) (updatedHb mbus.Heartbeat) {
	updatedHb = hb

	updatedHb.Vitals.Disks.System = getDiskStats(p, SYSTEM_DISK_PATH)

	if s.Disks.Ephemeral != "" {
		updatedHb.Vitals.Disks.Ephemeral = getDiskStats(p, EPHEMERAL_DISK_PATH)
	}

	if len(s.Disks.Persistent) == 1 {
		updatedHb.Vitals.Disks.Persistent = getDiskStats(p, PERSISTENT_DISK_PATH)
	}

	return
}

func getDiskStats(p platform.Platform, devicePath string) (stats mbus.DiskStats) {
	diskStats, err := p.GetDiskStats(devicePath)
	if err != nil {
		return
	}

	percent := float64(diskStats.Used) / float64(diskStats.Total) * 100
	inodePercent := float64(diskStats.InodeUsed) / float64(diskStats.InodeTotal) * 100

	stats.Percent = fmt.Sprintf("%.0f", percent)
	stats.InodePercent = fmt.Sprintf("%.0f", inodePercent)

	return
}
