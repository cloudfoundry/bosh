package action

import (
	bosherr "bosh/errors"
	boshplatform "bosh/platform"
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
	value, err = fs.ReadFile("/var/vcap/micro/apply_spec.json")
	if err != nil {
		err = bosherr.WrapError(err, "Opening micro apply spec file")
		return
	}

	return
}
