package action

import (
	boshappl "bosh/agent/applier"
	boshas "bosh/agent/applier/applyspec"
	bosherr "bosh/errors"
	boshplatform "bosh/platform"
	boshsettings "bosh/settings"
	boshsys "bosh/system"
	"encoding/json"
	"errors"
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

func (a applyAction) Run(payloadBytes []byte) (value interface{}, err error) {
	var payload struct {
		Arguments []interface{}
	}
	err = json.Unmarshal(payloadBytes, &payload)
	if err != nil {
		err = bosherr.WrapError(err, "Unmarshalling payload")
		return
	}

	if len(payload.Arguments) == 0 {
		err = errors.New("Not enough arguments, expected 1")
		return
	}

	applySpec, err := boshas.NewV1ApplySpecFromData(payload.Arguments[0])
	if err != nil {
		return
	}

	err = a.applier.Apply(applySpec)
	if err != nil {
		err = bosherr.WrapError(err, "Applying")
		return
	}

	spec, err := json.Marshal(payload.Arguments[0])
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
