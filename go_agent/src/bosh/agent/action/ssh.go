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
	settingsService boshsettings.Service
	platform        boshplatform.Platform
	dirProvider     boshdirs.DirectoriesProvider
}

func NewSsh(
	settingsService boshsettings.Service,
	platform boshplatform.Platform,
	dirProvider boshdirs.DirectoriesProvider,
) (action SshAction) {
	action.settingsService = settingsService
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

type SshResult struct {
	Command string `json:"command"`
	Status  string `json:"status"`
	IP      string `json:"ip,omitempty"`
}

func (a SshAction) Run(cmd string, params SshParams) (SshResult, error) {
	switch cmd {
	case "setup":
		return a.setupSsh(params)
	case "cleanup":
		return a.cleanupSsh(params)
	}

	return SshResult{}, errors.New("Unknown command for SSH method")
}

func (a SshAction) setupSsh(params SshParams) (SshResult, error) {
	var result SshResult

	boshSshPath := filepath.Join(a.dirProvider.BaseDir(), "bosh_ssh")

	err := a.platform.CreateUser(params.User, params.Password, boshSshPath)
	if err != nil {
		return result, bosherr.WrapError(err, "Creating user")
	}

	err = a.platform.AddUserToGroups(params.User, []string{boshsettings.VCAPUsername, boshsettings.AdminGroup})
	if err != nil {
		return result, bosherr.WrapError(err, "Adding user to groups")
	}

	err = a.platform.SetupSsh(params.PublicKey, params.User)
	if err != nil {
		return result, bosherr.WrapError(err, "Setting ssh public key")
	}

	settings := a.settingsService.GetSettings()

	defaultIP, found := settings.Networks.DefaultIP()
	if !found {
		return result, errors.New("No default ip could be found")
	}

	result = SshResult{
		Command: "setup",
		Status:  "success",
		IP:      defaultIP,
	}

	return result, nil
}

func (a SshAction) cleanupSsh(params SshParams) (SshResult, error) {
	err := a.platform.DeleteEphemeralUsersMatching(params.UserRegex)
	if err != nil {
		return SshResult{}, bosherr.WrapError(err, "Ssh Cleanup: Deleting Ephemeral Users")
	}

	result := SshResult{
		Command: "cleanup",
		Status:  "success",
	}

	return result, nil
}

func (a SshAction) Resume() (interface{}, error) {
	return nil, errors.New("not supported")
}

func (a SshAction) Cancel() error {
	return errors.New("not supported")
}
