package action

import (
	"errors"

	boshas "bosh/agent/applier/applyspec"
	bosherr "bosh/errors"
	boshjobsuper "bosh/jobsupervisor"
	boshntp "bosh/platform/ntp"
	boshvitals "bosh/platform/vitals"
	boshsettings "bosh/settings"
)

type GetStateAction struct {
	settingsService boshsettings.Service
	specService     boshas.V1Service
	jobSupervisor   boshjobsuper.JobSupervisor
	vitalsService   boshvitals.Service
	ntpService      boshntp.Service
}

func NewGetState(
	settingsService boshsettings.Service,
	specService boshas.V1Service,
	jobSupervisor boshjobsuper.JobSupervisor,
	vitalsService boshvitals.Service,
	ntpService boshntp.Service,
) (action GetStateAction) {
	action.settingsService = settingsService
	action.specService = specService
	action.jobSupervisor = jobSupervisor
	action.vitalsService = vitalsService
	action.ntpService = ntpService
	return
}

func (a GetStateAction) IsAsynchronous() bool {
	return false
}

func (a GetStateAction) IsPersistent() bool {
	return false
}

type GetStateV1ApplySpec struct {
	boshas.V1ApplySpec

	AgentID      string             `json:"agent_id"`
	BoshProtocol string             `json:"bosh_protocol"`
	JobState     string             `json:"job_state"`
	Vitals       *boshvitals.Vitals `json:"vitals,omitempty"`
	VM           boshsettings.VM    `json:"vm"`
	Ntp          boshntp.NTPInfo    `json:"ntp"`
}

func (a GetStateAction) Run(filters ...string) (GetStateV1ApplySpec, error) {
	spec, err := a.specService.Get()
	if err != nil {
		return GetStateV1ApplySpec{}, bosherr.WrapError(err, "Getting current spec")
	}

	var vitals boshvitals.Vitals
	var vitalsReference *boshvitals.Vitals

	if len(filters) > 0 && filters[0] == "full" {
		vitals, err = a.vitalsService.Get()
		if err != nil {
			return GetStateV1ApplySpec{}, bosherr.WrapError(err, "Building full vitals")
		}
		vitalsReference = &vitals
	}

	settings := a.settingsService.GetSettings()

	value := GetStateV1ApplySpec{
		spec,
		settings.AgentID,
		"1",
		a.jobSupervisor.Status(),
		vitalsReference,
		settings.VM,
		a.ntpService.GetInfo(),
	}

	if value.NetworkSpecs == nil {
		value.NetworkSpecs = map[string]boshas.NetworkSpec{}
	}
	if value.ResourcePoolSpecs == nil {
		value.ResourcePoolSpecs = map[string]interface{}{}
	}
	if value.PackageSpecs == nil {
		value.PackageSpecs = map[string]boshas.PackageSpec{}
	}

	return value, nil
}

func (a GetStateAction) Resume() (interface{}, error) {
	return nil, errors.New("not supported")
}

func (a GetStateAction) Cancel() error {
	return errors.New("not supported")
}
