package action

import (
	boshsettings "bosh/settings"
	boshsys "bosh/system"
	"encoding/json"
)

type getStateAction struct {
	settings boshsettings.Settings
	fs       boshsys.FileSystem
}

func newGetState(settings boshsettings.Settings, fs boshsys.FileSystem) (action getStateAction) {
	action.settings = settings
	action.fs = fs
	return
}

func (a getStateAction) Run([]byte) (value interface{}, err error) {
	content, err := a.fs.ReadFile(boshsettings.VCAP_BASE_DIR + "/bosh/spec.json")
	if err != nil {
		return
	}

	v := make(map[string]interface{})
	err = json.Unmarshal([]byte(content), &v)
	if err != nil {
		return
	}

	v["agent_id"] = a.settings.AgentId
	v["vm"] = a.settings.Vm
	v["job_state"] = "unknown"
	v["bosh_protocol"] = "1"
	value = v
	return
}
