package action

import (
	"errors"
	"path/filepath"

	bosherr "bosh/errors"
	boshplatform "bosh/platform"
	boshsettings "bosh/settings"
	boshdirs "bosh/settings/directories"
)

type SSHAction struct {
	settings    boshsettings.Service
	platform    boshplatform.Platform
	dirProvider boshdirs.DirectoriesProvider
}

func NewSSH(
	settings boshsettings.Service,
	platform boshplatform.Platform,
	dirProvider boshdirs.DirectoriesProvider,
) (action SSHAction) {
	action.settings = settings
	action.platform = platform
	action.dirProvider = dirProvider
	return
}

func (a SSHAction) IsAsynchronous() bool {
	return false
}

func (a SSHAction) IsPersistent() bool {
	return false
}

type SSHParams struct {
	UserRegex string `json:"user_regex"`
	User      string
	Password  string
	PublicKey string `json:"public_key"`
}

func (a SSHAction) Run(cmd string, params SSHParams) (value interface{}, err error) {
	switch cmd {
	case "setup":
		return a.setupSSH(params)
	case "cleanup":
		return a.cleanupSSH(params)
	}

	err = errors.New("Unknown command for SSH method")
	return
}

func (a SSHAction) setupSSH(params SSHParams) (value interface{}, err error) {
	boshSSHPath := filepath.Join(a.dirProvider.BaseDir(), "bosh_ssh")
	err = a.platform.CreateUser(params.User, params.Password, boshSSHPath)
	if err != nil {
		err = bosherr.WrapError(err, "Creating user")
		return
	}

	err = a.platform.AddUserToGroups(params.User, []string{boshsettings.VCAPUsername, boshsettings.AdminGroup})
	if err != nil {
		err = bosherr.WrapError(err, "Adding user to groups")
		return
	}

	err = a.platform.SetupSSH(params.PublicKey, params.User)
	if err != nil {
		err = bosherr.WrapError(err, "Setting ssh public key")
		return
	}

	defaultIP, found := a.settings.GetDefaultIP()

	if !found {
		err = errors.New("No default ip could be found")
		return
	}

	value = map[string]string{
		"command": "setup",
		"status":  "success",
		"ip":      defaultIP,
	}
	return
}

func (a SSHAction) cleanupSSH(params SSHParams) (value interface{}, err error) {
	err = a.platform.DeleteEphemeralUsersMatching(params.UserRegex)
	if err != nil {
		err = bosherr.WrapError(err, "SSH Cleanup: Deleting Ephemeral Users")
		return
	}

	value = map[string]string{
		"command": "cleanup",
		"status":  "success",
	}
	return
}

func (a SSHAction) Resume() (interface{}, error) {
	return nil, errors.New("not supported")
}

func (a SSHAction) Cancel() error {
	return errors.New("not supported")
}
