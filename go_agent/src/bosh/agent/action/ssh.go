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
	settingsService boshsettings.Service
	platform        boshplatform.Platform
	dirProvider     boshdirs.DirectoriesProvider
}

func NewSSH(
	settingsService boshsettings.Service,
	platform boshplatform.Platform,
	dirProvider boshdirs.DirectoriesProvider,
) (action SSHAction) {
	action.settingsService = settingsService
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

type SSHResult struct {
	Command string `json:"command"`
	Status  string `json:"status"`
	IP      string `json:"ip,omitempty"`
}

func (a SSHAction) Run(cmd string, params SSHParams) (SSHResult, error) {
	switch cmd {
	case "setup":
		return a.setupSSH(params)
	case "cleanup":
		return a.cleanupSSH(params)
	}

	return SSHResult{}, errors.New("Unknown command for SSH method")
}

func (a SSHAction) setupSSH(params SSHParams) (SSHResult, error) {
	var result SSHResult

	boshSSHPath := filepath.Join(a.dirProvider.BaseDir(), "bosh_ssh")

	err := a.platform.CreateUser(params.User, params.Password, boshSSHPath)
	if err != nil {
		return result, bosherr.WrapError(err, "Creating user")
	}

	err = a.platform.AddUserToGroups(params.User, []string{boshsettings.VCAPUsername, boshsettings.AdminGroup})
	if err != nil {
		return result, bosherr.WrapError(err, "Adding user to groups")
	}

	err = a.platform.SetupSSH(params.PublicKey, params.User)
	if err != nil {
		return result, bosherr.WrapError(err, "Setting ssh public key")
	}

	settings := a.settingsService.GetSettings()

	defaultIP, found := settings.Networks.DefaultIP()
	if !found {
		return result, errors.New("No default ip could be found")
	}

	result = SSHResult{
		Command: "setup",
		Status:  "success",
		IP:      defaultIP,
	}

	return result, nil
}

func (a SSHAction) cleanupSSH(params SSHParams) (SSHResult, error) {
	err := a.platform.DeleteEphemeralUsersMatching(params.UserRegex)
	if err != nil {
		return SSHResult{}, bosherr.WrapError(err, "SSH Cleanup: Deleting Ephemeral Users")
	}

	result := SSHResult{
		Command: "cleanup",
		Status:  "success",
	}

	return result, nil
}

func (a SSHAction) Resume() (interface{}, error) {
	return nil, errors.New("not supported")
}

func (a SSHAction) Cancel() error {
	return errors.New("not supported")
}
