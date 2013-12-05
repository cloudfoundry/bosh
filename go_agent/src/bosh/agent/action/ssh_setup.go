package action

import (
	bosherr "bosh/errors"
	boshsettings "bosh/settings"
	"errors"
	"path/filepath"
)

func (a sshAction) setupSsh(params sshParams) (value interface{}, err error) {
	user, pwd, key, err := params.getSshSetupData()
	if err != nil {
		return
	}

	boshSshPath := filepath.Join(boshsettings.VCAP_BASE_DIR, "bosh_ssh")
	err = a.platform.CreateUser(user, pwd, boshSshPath)
	if err != nil {
		err = bosherr.WrapError(err, "Creating user")
		return
	}

	err = a.platform.AddUserToGroups(user, []string{boshsettings.VCAP_USERNAME, boshsettings.ADMIN_GROUP})
	if err != nil {
		err = bosherr.WrapError(err, "Adding user to groups")
		return
	}

	err = a.platform.SetupSsh(key, user)
	if err != nil {
		err = bosherr.WrapError(err, "Setting ssh public key")
		return
	}

	defaultIp, found := a.settings.GetDefaultIp()

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
