package action

import (
	boshas "bosh/agent/applier/applyspec"
	bosherr "bosh/errors"
	boshjobsuper "bosh/jobsupervisor"
	boshstats "bosh/platform/stats"
	boshsettings "bosh/settings"
)

type getStateAction struct {
	settings       boshsettings.Service
	specService    boshas.V1Service
	jobSupervisor  boshjobsuper.JobSupervisor
	statsCollector boshstats.StatsCollector
}

func newGetState(settings boshsettings.Service,
	specService boshas.V1Service,
	jobSupervisor boshjobsuper.JobSupervisor,
	statsCollector boshstats.StatsCollector) (action getStateAction) {
	action.settings = settings
	action.specService = specService
	action.jobSupervisor = jobSupervisor
	action.statsCollector = statsCollector
	return
}

func (a getStateAction) IsAsynchronous() bool {
	return false
}

type getStateV1ApplySpec struct {
	boshas.V1ApplySpec

	AgentId      string           `json:"agent_id"`
	BoshProtocol string           `json:"bosh_protocol"`
	JobState     string           `json:"job_state"`
	Vitals       getStateV1Vitals `json:"vitals"`
	Vm           boshsettings.Vm  `json:"vm"`
}

type getStateV1Vitals struct {
	CPU  getStateV1VitalsCPU    `json:"cpu"`
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

func (a getStateAction) Run(filters ...string) (value getStateV1ApplySpec, err error) {
	spec, getSpecErr := a.specService.Get()
	if getSpecErr != nil {
		spec = boshas.V1ApplySpec{}
	}

	vitals := getStateV1Vitals{}
	if len(filters) > 0 && filters[0] == "full" {
		var (
			loadStats boshstats.CpuLoad
			cpuStats  boshstats.CpuStats
			memStats  boshstats.MemStats
			swapStats boshstats.MemStats
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

		vitals = getStateV1Vitals{
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
