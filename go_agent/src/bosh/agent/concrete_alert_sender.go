package agent

import (
	"strings"

	boshalert "bosh/agent/alert"
	bosherr "bosh/errors"
	boshhandler "bosh/handler"
	boshsyslog "bosh/syslog"
	boshtime "bosh/time"
	boshuuid "bosh/uuid"
)

type concreteAlertSender struct {
	mbusHandler   boshhandler.Handler
	alertBuilder  boshalert.Builder
	uuidGenerator boshuuid.Generator
	timeService   boshtime.Service
}

func NewConcreteAlertSender(
	mbusHandler boshhandler.Handler,
	alertBuilder boshalert.Builder,
	uuidGenerator boshuuid.Generator,
	timeService boshtime.Service,
) concreteAlertSender {
	return concreteAlertSender{
		mbusHandler:   mbusHandler,
		alertBuilder:  alertBuilder,
		uuidGenerator: uuidGenerator,
		timeService:   timeService,
	}
}

func (as concreteAlertSender) SendAlert(monitAlert boshalert.MonitAlert) error {
	alert, err := as.alertBuilder.Build(monitAlert)
	if err != nil {
		return bosherr.WrapError(err, "Building alert")
	}

	if alert.Severity == boshalert.SeverityIgnored {
		return nil
	}

	err = as.mbusHandler.SendToHealthManager("alert", alert)
	if err != nil {
		return bosherr.WrapError(err, "Sending alert")
	}

	return nil
}

func (as concreteAlertSender) SendSSHAlert(message boshsyslog.Msg) error {
	var title string

	if strings.Contains(message.Content, "disconnected by user") {
		title = "SSH Logout"
	} else if strings.Contains(message.Content, "Accepted publickey for") {
		title = "SSH Login"
	} else {
		return nil
	}

	uuid, err := as.uuidGenerator.Generate()
	if err != nil {
		return bosherr.WrapError(err, "Generating uuid")
	}

	alert := boshalert.Alert{
		ID:        uuid,
		Severity:  boshalert.SeverityWarning,
		Title:     title,
		Summary:   message.Content,
		CreatedAt: as.timeService.Now().Unix(),
	}

	err = as.mbusHandler.SendToHealthManager("alert", alert)
	if err != nil {
		return bosherr.WrapError(err, "Sending alert")
	}

	return nil
}
