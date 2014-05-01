package action

import (
	"errors"
	"path/filepath"

	bosherr "bosh/errors"
	boshplatform "bosh/platform"
	boshsettings "bosh/settings"
	boshdirs "bosh/settings/directories"
)

type SshAction struct {
	settings    boshsettings.Service
	platform    boshplatform.Platform
	dirProvider boshdirs.DirectoriesProvider
}

func NewSsh(
	settings boshsettings.Service,
	platform boshplatform.Platform,
	dirProvider boshdirs.DirectoriesProvider,
) (action SshAction) {
	action.settings = settings
	action.platform = platform
	action.dirProvider = dirProvider
	return
}

func (a SshAction) IsAsynchronous() bool {
	return false
}

func (a SshAction) IsPersistent() bool {
	return false
}

type SshParams struct {
	UserRegex string `json:"user_regex"`
	User      string
	Password  string
	PublicKey string `json:"public_key"`
}

func (a SshAction) Run(cmd string, params SshParams) (value interface{}, err error) {
	switch cmd {
	case "setup":
		return a.setupSsh(params)
	case "cleanup":
		return a.cleanupSsh(params)
	}

	err = errors.New("Unknown command for SSH method")
	return
}

func (a SshAction) setupSsh(params SshParams) (value interface{}, err error) {
	boshSshPath := filepath.Join(a.dirProvider.BaseDir(), "bosh_ssh")
	err = a.platform.CreateUser(params.User, params.Password, boshSshPath)
	if err != nil {
		err = bosherr.WrapError(err, "Creating user")
		return
	}

	err = a.platform.AddUserToGroups(params.User, []string{boshsettings.VCAPUsername, boshsettings.AdminGroup})
	if err != nil {
		err = bosherr.WrapError(err, "Adding user to groups")
		return
	}

	err = a.platform.SetupSsh(params.PublicKey, params.User)
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

func (a SshAction) cleanupSsh(params SshParams) (value interface{}, err error) {
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

func (a SshAction) Resume() (interface{}, error) {
	return nil, errors.New("not supported")
}

func (a SshAction) Cancel() error {
	return errors.New("not supported")
}
