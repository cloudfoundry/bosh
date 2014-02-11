package action

import (
	boshplatform "bosh/platform"
	boshsys "bosh/system"
	"os"
	"time"
)

type PrepareNetworkChangeAction struct {
	fs                      boshsys.FileSystem
	waitToKillAgentInterval time.Duration
}

func NewPrepareNetworkChange(platform boshplatform.Platform) (prepareAction PrepareNetworkChangeAction) {
	prepareAction.fs = platform.GetFs()
	prepareAction.waitToKillAgentInterval = 1 * time.Second
	return
}

func (a PrepareNetworkChangeAction) IsAsynchronous() bool {
	return false
}

func (a PrepareNetworkChangeAction) Run() (value interface{}, err error) {
	a.fs.RemoveAll("/etc/udev/rules.d/70-persistent-net.rules")

	go a.killAgent()

	value = "ok"
	return
}

func (a PrepareNetworkChangeAction) killAgent() {
	time.Sleep(a.waitToKillAgentInterval)
	os.Exit(0)
	return
}
