package action

import (
	bosherr "bosh/errors"
	boshplatform "bosh/platform"
	boshsettings "bosh/settings"
	"encoding/json"
	"errors"
)

type sshAction struct {
	settings boshsettings.NetworkSettings
	platform boshplatform.Platform
}

func newSsh(settings boshsettings.NetworkSettings, platform boshplatform.Platform) (action sshAction) {
	action.settings = settings
	action.platform = platform
	return
}

func (a sshAction) Run(payloadBytes []byte) (value interface{}, err error) {
	cmd, params, err := extractCommand(payloadBytes)
	if err != nil {
		err = bosherr.WrapError(err, "Extracting ssh command")
		return
	}

	switch cmd {
	case "setup":
		return a.setupSsh(params)
	case "cleanup":
		return a.cleanupSsh(params)
	}

	err = errors.New("Unknown command for SSH method")
	return
}

func extractCommand(payloadBytes []byte) (cmd string, params sshParams, err error) {
	var payload struct {
		Arguments []interface{}
	}

	err = json.Unmarshal(payloadBytes, &payload)
	if err != nil {
		err = bosherr.WrapError(err, "Parsing payload")
		return
	}

	cmd, ok := payload.Arguments[0].(string)
	if !ok {
		err = payloadErr("command")
		return
	}

	paramsMap, ok := payload.Arguments[1].(map[string]interface{})
	params = sshParams(paramsMap)
	if !ok {
		err = payloadErr("params")
		return
	}

	return
}

func payloadErr(attr string) error {
	return bosherr.New("Parsing %s in payload", attr)
}
