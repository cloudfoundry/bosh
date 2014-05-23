package action

import (
	"errors"

	boshas "bosh/agent/applier/applyspec"
	boshdrain "bosh/agent/drain"
	bosherr "bosh/errors"
	boshjobsuper "bosh/jobsupervisor"
	boshnotif "bosh/notification"
)

type DrainAction struct {
	drainScriptProvider boshdrain.DrainScriptProvider
	notifier            boshnotif.Notifier
	specService         boshas.V1Service
	jobSupervisor       boshjobsuper.JobSupervisor
}

func NewDrain(
	notifier boshnotif.Notifier,
	specService boshas.V1Service,
	drainScriptProvider boshdrain.DrainScriptProvider,
	jobSupervisor boshjobsuper.JobSupervisor,
) (drain DrainAction) {
	drain.notifier = notifier
	drain.specService = specService
	drain.drainScriptProvider = drainScriptProvider
	drain.jobSupervisor = jobSupervisor
	return
}

func (a DrainAction) IsAsynchronous() bool {
	return true
}

func (a DrainAction) IsPersistent() bool {
	return false
}

type DrainType string

const (
	DrainTypeUpdate   DrainType = "update"
	DrainTypeStatus   DrainType = "status"
	DrainTypeShutdown DrainType = "shutdown"
)

func (a DrainAction) Run(drainType DrainType, newSpecs ...boshas.V1ApplySpec) (int, error) {
	currentSpec, err := a.specService.Get()
	if err != nil {
		return 0, bosherr.WrapError(err, "Getting current spec")
	}

	if len(currentSpec.JobSpec.Template) == 0 {
		if drainType == DrainTypeStatus {
			return 0, bosherr.New("Check Status on Drain action requires job spec")
		}
		return 0, nil
	}

	err = a.jobSupervisor.Unmonitor()
	if err != nil {
		return 0, bosherr.WrapError(err, "Unmonitoring services")
	}

	drainScript := a.drainScriptProvider.NewDrainScript(currentSpec.JobSpec.Template)

	var newSpec *boshas.V1ApplySpec
	var params boshdrain.DrainScriptParams

	if len(newSpecs) > 0 {
		newSpec = &newSpecs[0]
	}

	switch drainType {
	case DrainTypeUpdate:
		if newSpec == nil {
			return 0, bosherr.New("Drain update requires new spec")
		}

		params = boshdrain.NewUpdateDrainParams(currentSpec, *newSpec)

	case DrainTypeShutdown:
		err = a.notifier.NotifyShutdown()
		if err != nil {
			return 0, bosherr.WrapError(err, "Notifying shutdown")
		}

		params = boshdrain.NewShutdownDrainParams(currentSpec, newSpec)

	case DrainTypeStatus:
		params = boshdrain.NewStatusDrainParams(currentSpec, newSpec)
	}

	if !drainScript.Exists() {
		if drainType == DrainTypeStatus {
			return 0, bosherr.New("Check Status on Drain action requires a valid drain script")
		}
		return 0, nil
	}

	value, err := drainScript.Run(params)
	if err != nil {
		return 0, bosherr.WrapError(err, "Running Drain Script")
	}

	return value, nil
}

func (a DrainAction) Resume() (interface{}, error) {
	return nil, errors.New("not supported")
}

func (a DrainAction) Cancel() error {
	return errors.New("not supported")
}
