package action

import (
	bosherrors "bosh/errors"
	boshplatform "bosh/platform"
	boshsettings "bosh/settings"
	"encoding/json"
	"errors"
	"fmt"
	"path/filepath"
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
	cmd, user, pwd, key, err := extractPayloadData(payloadBytes)
	if err != nil {
		return
	}

	boshSshPath := filepath.Join(boshsettings.VCAP_BASE_DIR, "bosh_ssh")
	err = a.platform.CreateUser(user, pwd, boshSshPath)
	if err != nil {
		err = bosherrors.WrapError(err, "Error creating user")
		return
	}

	err = a.platform.AddUserToGroups(user, []string{boshsettings.VCAP_USERNAME, boshsettings.ADMIN_GROUP})
	if err != nil {
		err = bosherrors.WrapError(err, "Error adding user to groups")
		return
	}

	err = a.platform.SetupSsh(key, user)
	if err != nil {
		err = bosherrors.WrapError(err, "Error setting ssh public key")
		return
	}

	defaultIp, found := a.settings.Networks.DefaultIp()
	if !found {
		err = errors.New("No default ip could be found")
		return
	}

	value = map[string]string{
		"command": cmd,
		"status":  "success",
		"ip":      defaultIp,
	}
	return
}

func extractPayloadData(payloadBytes []byte) (cmd, user, pwd, key string, err error) {
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

	params, ok := payload.Arguments[1].(map[string]interface{})
	if !ok {
		err = payloadErr("params")
		return
	}

	user, err = extractParam(params, "user")
	if err != nil {
		return
	}

	pwd, err = extractParam(params, "password")
	if err != nil {
		return
	}

	key, err = extractParam(params, "public_key")
	return
}

func payloadErr(attr string) error {
	return errors.New("Error parsing command in payload arguments")
}

func extractParam(params map[string]interface{}, name string) (val string, err error) {
	if params[name] == nil {
		return
	}

	val, ok := params[name].(string)
	if !ok {
		err = payloadErr(name)
	}
	return
}
