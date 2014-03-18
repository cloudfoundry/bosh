package action

import (
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

func (a PrepareNetworkChangeAction) Run() (interface{}, error) {
	err := a.settingsService.ForceNextFetchInitialToRefresh()
	if err != nil {
		return nil, bosherr.WrapError(err, "Force initial settings refresh")
	}

	err = a.fs.RemoveAll("/etc/udev/rules.d/70-persistent-net.rules")
	if err != nil {
		return nil, bosherr.WrapError(err, "Removing network rules file")
	}

	go a.killAgent()

	return "ok", nil
}

func (a PrepareNetworkChangeAction) killAgent() {
	time.Sleep(a.waitToKillAgentInterval)

	os.Exit(0)

	return
}
