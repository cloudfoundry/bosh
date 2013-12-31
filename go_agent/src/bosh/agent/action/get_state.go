package action

import (
	boshas "bosh/agent/applier/applyspec"
	boshjobsuper "bosh/jobsupervisor"
	boshsettings "bosh/settings"
)

type getStateAction struct {
	settings      boshsettings.Service
	specService   boshas.V1Service
	jobSupervisor boshjobsuper.JobSupervisor
}

func newGetState(
	settings boshsettings.Service,
	specService boshas.V1Service,
	jobSupervisor boshjobsuper.JobSupervisor,
) (action getStateAction) {
	action.settings = settings
	action.specService = specService
	action.jobSupervisor = jobSupervisor
	return
}

func (a getStateAction) IsAsynchronous() bool {
	return false
}

type getStateV1ApplySpec struct {
	boshas.V1ApplySpec

	AgentId      string          `json:"agent_id"`
	Vm           boshsettings.Vm `json:"vm"`
	JobState     string          `json:"job_state"`
	BoshProtocol string          `json:"bosh_protocol"`
}

func (a getStateAction) Run() (value getStateV1ApplySpec, _ error) {
	spec, err := a.specService.Get()
	if err != nil {
		spec = boshas.V1ApplySpec{}
	}

	value = getStateV1ApplySpec{
		spec,
		a.settings.GetAgentId(),
		a.settings.GetVm(),
		a.jobSupervisor.Status(),
		"1",
	}

	return
}
