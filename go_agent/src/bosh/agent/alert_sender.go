package agent

import (
	boshalert "bosh/agent/alert"
	bosherr "bosh/errors"
	boshhandler "bosh/handler"
)

type AlertSender struct {
	mbusHandler  boshhandler.Handler
	alertBuilder boshalert.Builder
}

func NewAlertSender(
	mbusHandler boshhandler.Handler,
	alertBuilder boshalert.Builder,
) AlertSender {
	return AlertSender{
		mbusHandler:  mbusHandler,
		alertBuilder: alertBuilder,
	}
}

func (as AlertSender) SendAlert(monitAlert boshalert.MonitAlert) error {
	alert, err := as.alertBuilder.Build(monitAlert)
	if err != nil {
		return bosherr.WrapError(err, "Building alert")
	}

	if alert.Severity == boshalert.SeverityIgnored {
		return nil
	}

	err = as.mbusHandler.SendToHealthManager("alert", alert)
	if err != nil {
		return bosherr.WrapError(err, "Sending heartbeat")
	}

	return nil
}
