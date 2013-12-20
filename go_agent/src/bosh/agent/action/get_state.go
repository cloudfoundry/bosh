package action

import (
	bosherr "bosh/errors"
	boshmon "bosh/monitor"
	boshsettings "bosh/settings"
	boshsys "bosh/system"
	"encoding/json"
)

type getStateAction struct {
	settings boshsettings.Service
	fs       boshsys.FileSystem
	monitor  boshmon.Monitor
}

func newGetState(settings boshsettings.Service, fs boshsys.FileSystem, monitor boshmon.Monitor) (action getStateAction) {
	action.settings = settings
	action.fs = fs
	action.monitor = monitor
	return
}

func (a getStateAction) IsAsynchronous() bool {
	return false
}

func (a getStateAction) Run() (value interface{}, err error) {
	content, err := a.fs.ReadFile(boshsettings.VCAP_BASE_DIR + "/bosh/spec.json")
	if err != nil {
		err = bosherr.WrapError(err, "Reading spec from disk")
		return
	}

	v := make(map[string]interface{})
	err = json.Unmarshal([]byte(content), &v)
	if err != nil {
		err = bosherr.WrapError(err, "Unmarshalling spec")
		return
	}

	v["agent_id"] = a.settings.GetAgentId()
	v["vm"] = a.settings.GetVm()
	v["job_state"] = a.monitor.Status()
	v["bosh_protocol"] = "1"
	value = v
	return
}
