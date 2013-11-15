package action

import (
	bosherrors "bosh/errors"
	boshsettings "bosh/settings"
	"errors"
	"path/filepath"
)

func (a sshAction) setupSsh(params map[string]interface{}) (value interface{}, err error) {
	user, pwd, key, err := extractSshSetupData(params)
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
		"command": "setup",
		"status":  "success",
		"ip":      defaultIp,
	}
	return
}

func extractSshSetupData(params map[string]interface{}) (user, pwd, key string, err error) {
	user, err = extractStringParam(params, "user")
	if err != nil {
		return
	}

	pwd, err = extractStringParam(params, "password")
	if err != nil {
		return
	}

	key, err = extractStringParam(params, "public_key")
	return
}
