package action

import (
	bosherr "bosh/errors"
	boshplatform "bosh/platform"
	boshsettings "bosh/settings"
	boshdirs "bosh/settings/directories"
	"errors"
	"path/filepath"
)

type sshAction struct {
	settings    boshsettings.Service
	platform    boshplatform.Platform
	dirProvider boshdirs.DirectoriesProvider
}

func newSsh(settings boshsettings.Service, platform boshplatform.Platform, dirProvider boshdirs.DirectoriesProvider) (action sshAction) {
	action.settings = settings
	action.platform = platform
	action.dirProvider = dirProvider
	return
}

func (a sshAction) IsAsynchronous() bool {
	return false
}

type sshParams struct {
	UserRegex string `json:"user_regex"`
	User      string
	Password  string
	PublicKey string `json:"public_key"`
}

func (a sshAction) Run(cmd string, params sshParams) (value interface{}, err error) {
	switch cmd {
	case "setup":
		return a.setupSsh(params)
	case "cleanup":
		return a.cleanupSsh(params)
	}

	err = errors.New("Unknown command for SSH method")
	return
}

func (a sshAction) setupSsh(params sshParams) (value interface{}, err error) {
	boshSshPath := filepath.Join(a.dirProvider.BaseDir(), "bosh_ssh")
	err = a.platform.CreateUser(params.User, params.Password, boshSshPath)
	if err != nil {
		err = bosherr.WrapError(err, "Creating user")
		return
	}

	err = a.platform.AddUserToGroups(params.User, []string{boshsettings.VCAP_USERNAME, boshsettings.ADMIN_GROUP})
	if err != nil {
		err = bosherr.WrapError(err, "Adding user to groups")
		return
	}

	err = a.platform.SetupSsh(params.PublicKey, params.User)
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

func (a sshAction) cleanupSsh(params sshParams) (value interface{}, err error) {
	err = a.platform.DeleteEphemeralUsersMatching(params.UserRegex)
	if err != nil {
		err = bosherr.WrapError(err, "Ssh Cleanup: Deleting Ephemeral Users")
		return
	}

	value = map[string]string{
		"command": "cleanup",
		"status":  "success",
	}
	return
}
