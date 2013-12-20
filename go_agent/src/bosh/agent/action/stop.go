package action

import (
	bosherr "bosh/errors"
	boshmon "bosh/monitor"
)

type stopAction struct {
	monitor boshmon.Monitor
}

func newStop(monitor boshmon.Monitor) (stop stopAction) {
	stop = stopAction{
		monitor: monitor,
	}
	return
}

func (a stopAction) IsAsynchronous() bool {
	return true
}

func (s stopAction) Run() (value interface{}, err error) {
	err = s.monitor.Stop()
	if err != nil {
		err = bosherr.WrapError(err, "Stopping Monitored Services")
		return
	}

	value = "stopped"
	return
}
