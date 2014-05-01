package action

import (
	"errors"
	"os"
	"time"

	bosherr "bosh/errors"
	boshsettings "bosh/settings"
	boshsys "bosh/system"
)

type PrepareNetworkChangeAction struct {
	fs                      boshsys.FileSystem
	settingsService         boshsettings.Service
	waitToKillAgentInterval time.Duration
}

func NewPrepareNetworkChange(
	fs boshsys.FileSystem,
	settingsService boshsettings.Service,
) (prepareAction PrepareNetworkChangeAction) {
	prepareAction.fs = fs
	prepareAction.settingsService = settingsService
	prepareAction.waitToKillAgentInterval = 1 * time.Second
	return
}

func (a PrepareNetworkChangeAction) IsAsynchronous() bool {
	return false
}

func (a PrepareNetworkChangeAction) IsPersistent() bool {
	return false
}

func (a PrepareNetworkChangeAction) Run() (interface{}, error) {
	err := a.settingsService.InvalidateSettings()
	if err != nil {
		return nil, bosherr.WrapError(err, "Invalidating settings")
	}

	err = a.fs.RemoveAll("/etc/udev/rules.d/70-persistent-net.rules")
	if err != nil {
		return nil, bosherr.WrapError(err, "Removing network rules file")
	}

	go a.killAgent()

	// Since this is a synchronous action API consumer
	// expects to receive response before agent restarts itself.
	return "ok", nil
}

func (a PrepareNetworkChangeAction) killAgent() {
	time.Sleep(a.waitToKillAgentInterval)

	os.Exit(0)

	return
}

func (a PrepareNetworkChangeAction) Resume() (interface{}, error) {
	return nil, errors.New("not supported")
}

func (a PrepareNetworkChangeAction) Cancel() error {
	return errors.New("not supported")
}
