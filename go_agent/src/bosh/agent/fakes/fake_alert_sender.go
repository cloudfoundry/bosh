package fakes

import (
	boshalert "bosh/agent/alert"
	boshsyslog "bosh/syslog"
)

type FakeAlertSender struct {
	SendAlertMonitAlert boshalert.MonitAlert
	SendAlertErr        error

	SendSSHAlertMsg boshsyslog.Msg
	SendSSHAlertErr error
}

func (as *FakeAlertSender) SendAlert(monitAlert boshalert.MonitAlert) error {
	as.SendAlertMonitAlert = monitAlert
	return as.SendAlertErr
}

func (as *FakeAlertSender) SendSSHAlert(msg boshsyslog.Msg) error {
	as.SendSSHAlertMsg = msg
	return as.SendSSHAlertErr
}
