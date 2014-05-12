package action

import (
	"errors"

	boshappl "bosh/agent/applier"
	boshas "bosh/agent/applier/applyspec"
	bosherr "bosh/errors"
)

type ApplyAction struct {
	applier     boshappl.Applier
	specService boshas.V1Service
}

func NewApply(applier boshappl.Applier, specService boshas.V1Service) (action ApplyAction) {
	action.applier = applier
	action.specService = specService
	return
}

func (a ApplyAction) IsAsynchronous() bool {
	return true
}

func (a ApplyAction) IsPersistent() bool {
	return false
}

func (a ApplyAction) Run(desiredSpec boshas.V1ApplySpec) (string, error) {
	resolvedDesiredSpec, err := a.specService.ResolveDynamicNetworks(desiredSpec)
	if err != nil {
		return "", bosherr.WrapError(err, "Resolving dynamic networks")
	}

	if desiredSpec.ConfigurationHash != "" {
		currentSpec, err := a.specService.Get()
		if err != nil {
			return "", bosherr.WrapError(err, "Getting current spec")
		}

		err = a.applier.Apply(currentSpec, resolvedDesiredSpec)
		if err != nil {
			return "", bosherr.WrapError(err, "Applying")
		}
	}

	err = a.specService.Set(resolvedDesiredSpec)
	if err != nil {
		return "", bosherr.WrapError(err, "Persisting apply spec")
	}

	return "applied", nil
}

func (a ApplyAction) Resume() (interface{}, error) {
	return nil, errors.New("not supported")
}

func (a ApplyAction) Cancel() error {
	return errors.New("not supported")
}
