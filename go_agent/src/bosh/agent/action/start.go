package action

import (
	bosherr "bosh/errors"
	boshmon "bosh/monitor"
)

type startAction struct {
	monitor boshmon.Monitor
}

func newStart(monitor boshmon.Monitor) (start startAction) {
	start = startAction{
		monitor: monitor,
	}
	return
}

func (a startAction) IsAsynchronous() bool {
	return false
}

func (s startAction) Run() (value interface{}, err error) {
	err = s.monitor.Start()
	if err != nil {
		err = bosherr.WrapError(err, "Starting Monitored Services")
		return
	}

	value = "started"
	return
}
