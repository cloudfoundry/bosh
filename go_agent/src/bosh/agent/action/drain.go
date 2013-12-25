package action

import (
	boshas "bosh/agent/applier/applyspec"
	boshdrain "bosh/agent/drain"
	bosherr "bosh/errors"
	boshnotif "bosh/notification"
	boshsys "bosh/system"
)

type drainAction struct {
	cmdRunner   boshsys.CmdRunner
	fs          boshsys.FileSystem
	notifier    boshnotif.Notifier
	specService boshas.V1Service
}

func newDrain(cmdRunner boshsys.CmdRunner, fs boshsys.FileSystem, notifier boshnotif.Notifier, specService boshas.V1Service) (drain drainAction) {
	drain.cmdRunner = cmdRunner
	drain.fs = fs
	drain.notifier = notifier
	drain.specService = specService
	return
}

func (a drainAction) IsAsynchronous() bool {
	return true
}

type drainType string

const (
	drainTypeUpdate   drainType = "update"
	drainTypeStatus             = "status"
	drainTypeShutdown           = "shutdown"
)

func (a drainAction) Run(drainType drainType, newSpecs ...boshas.V1ApplySpec) (value interface{}, err error) {
	value = 0

	currentSpec, err := a.specService.Get()
	if err != nil {
		err = bosherr.WrapError(err, "Getting current spec")
		return
	}

	drainScript := boshdrain.NewConcreteDrainScript(a.fs, a.cmdRunner, currentSpec.JobSpec.Template)
	var params boshdrain.DrainScriptParams

	switch drainType {
	case drainTypeUpdate:
		if len(newSpecs) == 0 {
			err = bosherr.New("Drain update requires new spec")
			return
		}
		newSpec := newSpecs[0]

		params = boshdrain.NewUpdateDrainParams(currentSpec, newSpec)
	case drainTypeShutdown:
		err = a.notifier.NotifyShutdown()
		if err != nil {
			err = bosherr.WrapError(err, "Notifying shutdown")
			return
		}
		params = boshdrain.NewShutdownDrainParams()
	case drainTypeStatus:
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
