package action

import (
	"errors"

	bosherr "bosh/errors"
	boshsettings "bosh/settings"
	boshsys "bosh/system"
)

type PrepareConfigureNetworksAction struct {
	fs              boshsys.FileSystem
	settingsService boshsettings.Service
}

func NewPrepareConfigureNetworks(
	fs boshsys.FileSystem,
	settingsService boshsettings.Service,
) (prepareAction PrepareConfigureNetworksAction) {
	prepareAction.fs = fs
	prepareAction.settingsService = settingsService
	return
}

func (a PrepareConfigureNetworksAction) IsAsynchronous() bool {
	return false
}

func (a PrepareConfigureNetworksAction) IsPersistent() bool {
	return false
}

func (a PrepareConfigureNetworksAction) Run() (interface{}, error) {
	err := a.settingsService.InvalidateSettings()
	if err != nil {
		return nil, bosherr.WrapError(err, "Invalidating settings")
	}

	err = a.fs.RemoveAll("/etc/udev/rules.d/70-persistent-net.rules")
	if err != nil {
		return nil, bosherr.WrapError(err, "Removing network rules file")
	}

	return "ok", nil
}

func (a PrepareConfigureNetworksAction) Resume() (interface{}, error) {
	return nil, errors.New("not supported")
}

func (a PrepareConfigureNetworksAction) Cancel() error {
	return errors.New("not supported")
}
