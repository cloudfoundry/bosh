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

func (a ApplyAction) Run(applySpec boshas.V1ApplySpec) (interface{}, error) {
	if applySpec.ConfigurationHash != "" {
		err := a.applier.Apply(applySpec)
		if err != nil {
			return "", bosherr.WrapError(err, "Applying")
		}
	}

	err := a.specService.Set(applySpec)
	if err != nil {
		return "", bosherr.WrapError(err, "Persisting apply spec")
	}

	return "applied", nil
}

func (a ApplyAction) Resume() (interface{}, error) {
	return nil, errors.New("not supported")
}
