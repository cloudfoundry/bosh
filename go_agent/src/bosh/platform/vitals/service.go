package vitals

import (
	bosherr "bosh/errors"
	boshstats "bosh/platform/stats"
	boshdirs "bosh/settings/directories"
	"fmt"
)

type Service interface {
	Get() (vitals Vitals, err error)
}

type concreteService struct {
	statsCollector boshstats.StatsCollector
	dirProvider    boshdirs.DirectoriesProvider
}

func NewService(statsCollector boshstats.StatsCollector, dirProvider boshdirs.DirectoriesProvider) Service {
	return concreteService{
		statsCollector: statsCollector,
		dirProvider:    dirProvider,
	}
}

func (s concreteService) Get() (vitals Vitals, err error) {
	var (
		loadStats boshstats.CpuLoad
		cpuStats  boshstats.CpuStats
		memStats  boshstats.Usage
		swapStats boshstats.Usage
		diskStats DiskVitals
	)

	loadStats, err = s.statsCollector.GetCpuLoad()
	if err != nil {
		err = bosherr.WrapError(err, "Getting CPU Load")
		return
	}

	cpuStats, err = s.statsCollector.GetCpuStats()
	if err != nil {
		err = bosherr.WrapError(err, "Getting CPU Stats")
		return
	}

	memStats, err = s.statsCollector.GetMemStats()
	if err != nil {
		err = bosherr.WrapError(err, "Getting Memory Stats")
		return
	}

	swapStats, err = s.statsCollector.GetSwapStats()
	if err != nil {
		err = bosherr.WrapError(err, "Getting Swap Stats")
		return
	}

	diskStats, err = s.getDiskStats()
	if err != nil {
		err = bosherr.WrapError(err, "Getting Disk Stats")
		return
	}

	vitals = Vitals{
		Load: []string{
			fmt.Sprintf("%.2f", loadStats.One),
			fmt.Sprintf("%.2f", loadStats.Five),
			fmt.Sprintf("%.2f", loadStats.Fifteen),
		},
		CPU: CPUVitals{
			User: cpuStats.UserPercent().FormatFractionOf100(1),
			Sys:  cpuStats.SysPercent().FormatFractionOf100(1),
			Wait: cpuStats.WaitPercent().FormatFractionOf100(1),
		},
		Mem:  createMemVitals(memStats),
		Swap: createMemVitals(swapStats),
		Disk: diskStats,
	}
	return
}

func (s concreteService) getDiskStats() (diskStats DiskVitals, err error) {
	disks := map[string]string{
		"/": "system",
		s.dirProvider.DataDir():  "ephemeral",
		s.dirProvider.StoreDir(): "persistent",
	}
	diskStats = make(DiskVitals, len(disks))

	for path, name := range disks {
		diskStats, err = s.addDiskStats(diskStats, path, name)
		if err != nil {
			return
		}
	}

	return
}

func (s concreteService) addDiskStats(diskStats DiskVitals, path, name string) (updated DiskVitals, err error) {
	updated = diskStats

	stat, diskErr := s.statsCollector.GetDiskStats(path)
	if diskErr != nil {
		if path == "/" {
			err = bosherr.WrapError(diskErr, "Getting Disk Stats for /")
		}
		return
	}

	updated[name] = SpecificDiskVitals{
		Percent:      stat.DiskUsage.Percent().FormatFractionOf100(0),
		InodePercent: stat.InodeUsage.Percent().FormatFractionOf100(0),
	}
	return
}

func createMemVitals(memUsage boshstats.Usage) MemoryVitals {
	return MemoryVitals{
		Percent: memUsage.Percent().FormatFractionOf100(0),
		Kb:      fmt.Sprintf("%d", memUsage.Used/1024),
	}
}
