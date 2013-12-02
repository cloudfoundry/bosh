package action

import (
	apply_spec "bosh/agent/apply_spec"
	bosherr "bosh/errors"
	boshplatform "bosh/platform"
	boshsettings "bosh/settings"
	boshsys "bosh/system"
	"encoding/json"
	"errors"
	"path/filepath"
)

type applyAction struct {
	fs       boshsys.FileSystem
	platform boshplatform.Platform
}

func newApply(fs boshsys.FileSystem, platform boshplatform.Platform) (action applyAction) {
	action.fs = fs
	action.platform = platform
	return
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

	applySpec, err := apply_spec.NewApplySpecFromData(payload.Arguments[0])
	if err != nil {
		return
	}

	err = a.platform.SetupLogrotate(
		boshsettings.VCAP_USERNAME,
		boshsettings.VCAP_BASE_DIR,
		applySpec.MaxLogFileSize(),
	)
	if err != nil {
		err = bosherr.WrapError(err, "Logrotate setup failed")
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
