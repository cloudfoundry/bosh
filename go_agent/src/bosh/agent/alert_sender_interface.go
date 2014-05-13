package agent

import (
	boshalert "bosh/agent/alert"
	boshsyslog "bosh/syslog"
)

type AlertSender interface {
	SendAlert(boshalert.MonitAlert) error
	SendSSHAlert(boshsyslog.Msg) error
}
