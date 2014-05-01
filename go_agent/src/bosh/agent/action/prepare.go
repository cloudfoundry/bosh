package action

import (
	"errors"

	boshappl "bosh/agent/applier"
	boshas "bosh/agent/applier/applyspec"
	bosherr "bosh/errors"
)

type PrepareAction struct {
	applier boshappl.Applier
}

func NewPrepare(applier boshappl.Applier) (action PrepareAction) {
	action.applier = applier
	return action
}

func (a PrepareAction) IsAsynchronous() bool {
	return true
}

func (a PrepareAction) IsPersistent() bool {
	return false
}

func (a PrepareAction) Run(desiredSpec boshas.V1ApplySpec) (string, error) {
	err := a.applier.Prepare(desiredSpec)
	if err != nil {
		return "", bosherr.WrapError(err, "Preparing apply spec")
	}

	return "prepared", nil
}

func (a PrepareAction) Resume() (interface{}, error) {
	return nil, errors.New("not supported")
}

func (a PrepareAction) Cancel() error {
	return errors.New("not supported")
}
