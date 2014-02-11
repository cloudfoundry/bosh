package action

import (
	boshas "bosh/agent/applier/applyspec"
	boshdrain "bosh/agent/drain"
	bosherr "bosh/errors"
	boshnotif "bosh/notification"
)

type DrainAction struct {
	drainScriptProvider boshdrain.DrainScriptProvider
	notifier            boshnotif.Notifier
	specService         boshas.V1Service
}

func NewDrain(notifier boshnotif.Notifier, specService boshas.V1Service, drainScriptProvider boshdrain.DrainScriptProvider) (drain DrainAction) {
	drain.notifier = notifier
	drain.specService = specService
	drain.drainScriptProvider = drainScriptProvider
	return
}

func (a DrainAction) IsAsynchronous() bool {
	return true
}

type DrainType string

const (
	DrainTypeUpdate   DrainType = "update"
	DrainTypeStatus             = "status"
	DrainTypeShutdown           = "shutdown"
)

func (a DrainAction) Run(drainType DrainType, newSpecs ...boshas.V1ApplySpec) (value interface{}, err error) {
	value = 0

	currentSpec, err := a.specService.Get()
	if err != nil {
		err = bosherr.WrapError(err, "Getting current spec")
		return
	}

	drainScript := a.drainScriptProvider.NewDrainScript(currentSpec.JobSpec.Template)
	var params boshdrain.DrainScriptParams

	switch drainType {
	case DrainTypeUpdate:
		if len(newSpecs) == 0 {
			err = bosherr.New("Drain update requires new spec")
			return
		}
		newSpec := newSpecs[0]

		params = boshdrain.NewUpdateDrainParams(currentSpec, newSpec)
	case DrainTypeShutdown:
		err = a.notifier.NotifyShutdown()
		if err != nil {
			err = bosherr.WrapError(err, "Notifying shutdown")
			return
		}
		params = boshdrain.NewShutdownDrainParams()
	case DrainTypeStatus:
		if !drainScript.Exists() {
			err = bosherr.New("Check Status on Drain action requires a valid drain script")
			return
		}
		params = boshdrain.NewStatusDrainParams()
	}

	if !drainScript.Exists() {
		return
	}

	value, err = drainScript.Run(params)
	if err != nil {
		err = bosherr.WrapError(err, "Running Drain Script")
		return
	}
	return
}
