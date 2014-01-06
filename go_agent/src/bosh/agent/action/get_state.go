package action

import (
	boshas "bosh/agent/applier/applyspec"
	bosherr "bosh/errors"
	boshjobsuper "bosh/jobsupervisor"
	boshntp "bosh/platform/ntp"
	boshvitals "bosh/platform/vitals"
	boshsettings "bosh/settings"
)

type getStateAction struct {
	settings      boshsettings.Service
	specService   boshas.V1Service
	jobSupervisor boshjobsuper.JobSupervisor
	vitalsService boshvitals.Service
	ntpService    boshntp.Service
}

func newGetState(settings boshsettings.Service,
	specService boshas.V1Service,
	jobSupervisor boshjobsuper.JobSupervisor,
	vitalsService boshvitals.Service,
	ntpService boshntp.Service,
) (action getStateAction) {
	action.settings = settings
	action.specService = specService
	action.jobSupervisor = jobSupervisor
	action.vitalsService = vitalsService
	action.ntpService = ntpService
	return
}

func (a getStateAction) IsAsynchronous() bool {
	return false
}

type getStateV1ApplySpec struct {
	boshas.V1ApplySpec

	AgentId      string             `json:"agent_id"`
	BoshProtocol string             `json:"bosh_protocol"`
	JobState     string             `json:"job_state"`
	Vitals       *boshvitals.Vitals `json:"vitals,omitempty"`
	Vm           boshsettings.Vm    `json:"vm"`
	Ntp          boshntp.NTPInfo    `json:"ntp"`
}

func (a getStateAction) Run(filters ...string) (value getStateV1ApplySpec, err error) {
	spec, getSpecErr := a.specService.Get()
	if getSpecErr != nil {
		spec = boshas.V1ApplySpec{}
	}

	var vitals boshvitals.Vitals
	var vitalsReference *boshvitals.Vitals

	if len(filters) > 0 && filters[0] == "full" {
		vitals, err = a.vitalsService.Get()
		if err != nil {
			err = bosherr.WrapError(err, "Building full vitals")
			return
		}
		vitalsReference = &vitals
	}

	value = getStateV1ApplySpec{
		spec,
		a.settings.GetAgentId(),
		"1",
		a.jobSupervisor.Status(),
		vitalsReference,
		a.settings.GetVm(),
		a.ntpService.GetInfo(),
	}

	return
}
