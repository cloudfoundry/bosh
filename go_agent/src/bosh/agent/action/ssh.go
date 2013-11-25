package action

import (
	boshplatform "bosh/platform"
	boshsettings "bosh/settings"
	"encoding/json"
	"errors"
	"fmt"
)

type sshAction struct {
	settings boshsettings.Settings
	platform boshplatform.Platform
}

func newSsh(settings boshsettings.Settings, platform boshplatform.Platform) (action sshAction) {
	action.settings = settings
	action.platform = platform
	return
}

func (a sshAction) Run(payloadBytes []byte) (value interface{}, err error) {
	cmd, params, err := extractCommand(payloadBytes)
	if err != nil {
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
		err = errors.New(fmt.Sprintf("Error parsing payload: %s", err.Error()))
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
	return errors.New(fmt.Sprintf("Error parsing %s in payload", attr))
}
