package action

import (
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

func (a ApplyAction) Run(applySpec boshas.V1ApplySpec) (value interface{}, err error) {
	if applySpec.ConfigurationHash != "" {
		err = a.applier.Apply(applySpec)
		if err != nil {
			err = bosherr.WrapError(err, "Applying")
			return
		}
	}

	err = a.specService.Set(applySpec)
	if err != nil {
		err = bosherr.WrapError(err, "Persisting apply spec")
		return
	}
	value = "applied"
	return
}
