package action

import (
	boshas "bosh/agent/applier/applyspec"
	bosherr "bosh/errors"
	boshjobsuper "bosh/jobsupervisor"
	boshstats "bosh/platform/stats"
	boshsettings "bosh/settings"
	boshdirs "bosh/settings/directories"
	"fmt"
)

type getStateAction struct {
	settings       boshsettings.Service
	specService    boshas.V1Service
	jobSupervisor  boshjobsuper.JobSupervisor
	statsCollector boshstats.StatsCollector
	dirProvider    boshdirs.DirectoriesProvider
}

func newGetState(settings boshsettings.Service,
	specService boshas.V1Service,
	jobSupervisor boshjobsuper.JobSupervisor,
	statsCollector boshstats.StatsCollector,
	dirProvider boshdirs.DirectoriesProvider,
) (action getStateAction) {
	action.settings = settings
	action.specService = specService
	action.jobSupervisor = jobSupervisor
	action.statsCollector = statsCollector
	action.dirProvider = dirProvider
	return
}

func (a getStateAction) IsAsynchronous() bool {
	return false
}

type getStateV1ApplySpec struct {
	boshas.V1ApplySpec

	AgentId      string            `json:"agent_id"`
	BoshProtocol string            `json:"bosh_protocol"`
	JobState     string            `json:"job_state"`
	Vitals       *getStateV1Vitals `json:"vitals,omitempty"`
	Vm           boshsettings.Vm   `json:"vm"`
}

type getStateV1Vitals struct {
	CPU  getStateV1VitalsCPU    `json:"cpu"`
	Disk getStateV1VitalDisk    `json:"disk"`
	Load []float64              `json:"load"`
	Mem  getStateV1VitalsMemory `json:"mem"`
	Swap getStateV1VitalsMemory `json:"swap"`
}

type getStateV1VitalsCPU struct {
	Sys  uint64 `json:"sys"`
	User uint64 `json:"user"`
	Wait uint64 `json:"wait"`
}

type getStateV1VitalsMemory struct {
	Kb      uint64  `json:"kb"`
	Percent float64 `json:"percent"`
}

type getStateV1VitalDisk map[string]getStateV1VitalDiskStats

type getStateV1VitalDiskStats struct {
	InodePercent string `json:"inode_percent"`
	Percent      string `json:"percent"`
}

func (a getStateAction) Run(filters ...string) (value getStateV1ApplySpec, err error) {
	spec, getSpecErr := a.specService.Get()
	if getSpecErr != nil {
		spec = boshas.V1ApplySpec{}
	}

	var vitals *getStateV1Vitals

	if len(filters) > 0 && filters[0] == "full" {
		vitals, err = a.buildFullVitals()
		if err != nil {
			err = bosherr.WrapError(err, "Building full vitals")
			return
		}
	}

	value = getStateV1ApplySpec{
		spec,
		a.settings.GetAgentId(),
		"1",
		a.jobSupervisor.Status(),
		vitals,
		a.settings.GetVm(),
	}

	return
}

func (a getStateAction) buildFullVitals() (vitals *getStateV1Vitals, err error) {
	var (
		loadStats boshstats.CpuLoad
		cpuStats  boshstats.CpuStats
		memStats  boshstats.MemStats
		swapStats boshstats.MemStats
		diskStats getStateV1VitalDisk
	)

	loadStats, err = a.statsCollector.GetCpuLoad()
	if err != nil {
		err = bosherr.WrapError(err, "Getting CPU Load")
		return
	}

	cpuStats, err = a.statsCollector.GetCpuStats()
	if err != nil {
		err = bosherr.WrapError(err, "Getting CPU Stats")
		return
	}

	memStats, err = a.statsCollector.GetMemStats()
	if err != nil {
		err = bosherr.WrapError(err, "Getting Memory Stats")
		return
	}

	swapStats, err = a.statsCollector.GetSwapStats()
	if err != nil {
		err = bosherr.WrapError(err, "Getting Swap Stats")
		return
	}

	diskStats, err = a.getDiskStats()
	if err != nil {
		err = bosherr.WrapError(err, "Getting Disk Stats")
		return
	}

	vitals = &getStateV1Vitals{
		Load: []float64{
			loadStats.One,
			loadStats.Five,
			loadStats.Fifteen,
		},
		CPU: getStateV1VitalsCPU{
			User: cpuStats.User,
			Sys:  cpuStats.Sys,
			Wait: cpuStats.Wait,
		},
		Mem: getStateV1VitalsMemory{
			Percent: float64(memStats.Used) / float64(memStats.Total) * 100,
			Kb:      memStats.Used,
		},
		Swap: getStateV1VitalsMemory{
			Percent: float64(swapStats.Used) / float64(swapStats.Total) * 100,
			Kb:      swapStats.Used,
		},
		Disk: diskStats,
	}
	return
}

func (a getStateAction) getDiskStats() (diskStats getStateV1VitalDisk, err error) {
	disks := map[string]string{
		"/": "system",
		a.dirProvider.DataDir():  "ephemeral",
		a.dirProvider.StoreDir(): "persistent",
	}
	diskStats = make(getStateV1VitalDisk, len(disks))

	for path, name := range disks {
		diskStats, err = a.addDiskStats(diskStats, path, name)
		if err != nil {
			return
		}
	}

	return
}

func (a getStateAction) addDiskStats(diskStats getStateV1VitalDisk, path, name string) (updated getStateV1VitalDisk, err error) {
	updated = diskStats

	s, diskErr := a.statsCollector.GetDiskStats(path)
	if diskErr != nil {
		if path == "/" {
			err = bosherr.WrapError(diskErr, "Getting Disk Stats for /")
		}
		return
	}

	updated[name] = getStateV1VitalDiskStats{
		Percent:      fmt.Sprintf("%.0f", s.Percent()*100),
		InodePercent: fmt.Sprintf("%.0f", s.InodePercent()*100),
	}
	return
}
