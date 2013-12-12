package action

import (
	boshappl "bosh/agent/applier"
	boshas "bosh/agent/applier/applyspec"
	bosherr "bosh/errors"
	boshplatform "bosh/platform"
	boshsettings "bosh/settings"
	boshsys "bosh/system"
	"encoding/json"
	"path/filepath"
)

type applyAction struct {
	applier  boshappl.Applier
	fs       boshsys.FileSystem
	platform boshplatform.Platform
}

func newApply(applier boshappl.Applier, fs boshsys.FileSystem, platform boshplatform.Platform) (action applyAction) {
	action.applier = applier
	action.fs = fs
	action.platform = platform
	return
}

func (a applyAction) IsAsynchronous() bool {
	return true
}

func (a applyAction) Run(applySpec boshas.V1ApplySpec) (value interface{}, err error) {
	err = a.applier.Apply(applySpec)
	if err != nil {
		err = bosherr.WrapError(err, "Applying")
		return
	}

	err = a.persistApplySpec(applySpec)
	if err != nil {
		err = bosherr.WrapError(err, "Persisting apply spec")
	}
	return
}

func (a applyAction) persistApplySpec(applySpec boshas.V1ApplySpec) (err error) {
	spec, err := json.Marshal(applySpec)
	if err != nil {
		err = bosherr.WrapError(err, "Marshalling apply spec")
		return
	}

	specFilePath := filepath.Join(boshsettings.VCAP_BASE_DIR, "/bosh/spec.json")
	_, err = a.fs.WriteToFile(specFilePath, string(spec))
	if err != nil {
		err = bosherr.WrapError(err, "Writing spec to disk")
	}
	return
}
