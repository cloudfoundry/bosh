package action

import (
	boshas "bosh/agent/applier/applyspec"
	bosherr "bosh/errors"
	boshmon "bosh/monitor"
	boshsettings "bosh/settings"
)

type getStateAction struct {
	settings    boshsettings.Service
	specService boshas.V1Service
	monitor     boshmon.Monitor
}

func newGetState(settings boshsettings.Service, specService boshas.V1Service, monitor boshmon.Monitor) (action getStateAction) {
	action.settings = settings
	action.specService = specService
	action.monitor = monitor
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

func (a getStateAction) Run() (value getStateV1ApplySpec, err error) {
	spec, err := a.specService.Get()
	if err != nil {
		err = bosherr.WrapError(err, "Getting current spec")
		return
	}

	value = getStateV1ApplySpec{
		spec,
		a.settings.GetAgentId(),
		a.settings.GetVm(),
		a.monitor.Status(),
		"1",
	}

	return
}
