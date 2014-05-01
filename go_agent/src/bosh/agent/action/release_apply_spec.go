package action

import (
	"encoding/json"
	"errors"

	bosherr "bosh/errors"
	boshplatform "bosh/platform"
)

type ReleaseApplySpecAction struct {
	platform boshplatform.Platform
}

func NewReleaseApplySpec(platform boshplatform.Platform) (action ReleaseApplySpecAction) {
	action.platform = platform
	return
}

func (a ReleaseApplySpecAction) IsAsynchronous() bool {
	return false
}

func (a ReleaseApplySpecAction) IsPersistent() bool {
	return false
}

func (a ReleaseApplySpecAction) Run() (value interface{}, err error) {
	fs := a.platform.GetFs()
	specBytes, err := fs.ReadFile("/var/vcap/micro/apply_spec.json")
	if err != nil {
		err = bosherr.WrapError(err, "Opening micro apply spec file")
		return
	}

	err = json.Unmarshal([]byte(specBytes), &value)
	if err != nil {
		err = bosherr.WrapError(err, "Unmarshalling release apply spec")
		return
	}

	return
}

func (a ReleaseApplySpecAction) Resume() (interface{}, error) {
	return nil, errors.New("not supported")
}

func (a ReleaseApplySpecAction) Cancel() error {
	return errors.New("not supported")
}
