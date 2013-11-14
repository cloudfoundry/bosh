package action

import (
	boshsettings "bosh/settings"
	boshsys "bosh/system"
	"encoding/json"
	"errors"
	"path/filepath"
)

type applyAction struct {
	fs boshsys.FileSystem
}

func newApply(fs boshsys.FileSystem) (apply applyAction) {
	apply.fs = fs
	return
}

func (a applyAction) Run(payloadBytes []byte) (value interface{}, err error) {
	type payloadType struct {
		Arguments []interface{}
	}

	var payload payloadType
	err = json.Unmarshal(payloadBytes, &payload)
	if err != nil {
		return
	}

	if len(payload.Arguments) == 0 {
		err = errors.New("Not enough arguments, expected 1")
		return
	}

	spec, err := json.Marshal(payload.Arguments[0])
	if err != nil {
		return
	}

	specFilePath := filepath.Join(boshsettings.VCAP_BASE_DIR, "/bosh/spec.json")
	_, err = a.fs.WriteToFile(specFilePath, string(spec))
	return
}
