package action

import (
	bosherr "bosh/errors"
	boshplatform "bosh/platform"
	"encoding/json"
)

type releaseApplySpecAction struct {
	platform boshplatform.Platform
}

func newReleaseApplySpec(platform boshplatform.Platform) (action releaseApplySpecAction) {
	action.platform = platform
	return
}

func (a releaseApplySpecAction) IsAsynchronous() bool {
	return false
}

func (a releaseApplySpecAction) Run() (value interface{}, err error) {
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
