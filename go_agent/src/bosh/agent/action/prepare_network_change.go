package action

import (
	boshplatform "bosh/platform"
	boshsys "bosh/system"
	"os"
	"time"
)

type prepareNetworkChangeAction struct {
	fs                      boshsys.FileSystem
	waitToKillAgentInterval time.Duration
}

func newPrepareNetworkChange(platform boshplatform.Platform) (prepareAction prepareNetworkChangeAction) {
	prepareAction.fs = platform.GetFs()
	prepareAction.waitToKillAgentInterval = 1 * time.Second
	return
}

func (a prepareNetworkChangeAction) IsAsynchronous() bool {
	return false
}

func (a prepareNetworkChangeAction) Run() (value interface{}, err error) {
	a.fs.RemoveAll("/etc/udev/rules.d/70-persistent-net.rules")

	go a.killAgent()

	value = "ok"
	return
}

func (a prepareNetworkChangeAction) killAgent() {
	time.Sleep(a.waitToKillAgentInterval)
	os.Exit(0)
	return
}
