package action

import (
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

func (a PrepareConfigureNetworksAction) Run() (interface{}, error) {
	err := a.settingsService.ForceNextLoadToFetchSettings()
	if err != nil {
		return nil, bosherr.WrapError(err, "Force initial settings refresh")
	}

	err = a.fs.RemoveAll("/etc/udev/rules.d/70-persistent-net.rules")
	if err != nil {
		return nil, bosherr.WrapError(err, "Removing network rules file")
	}

	return "ok", nil
}
