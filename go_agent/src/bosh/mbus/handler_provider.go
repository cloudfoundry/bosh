package mbus

import (
	bosherr "bosh/errors"
	boshlog "bosh/logger"
	boshsettings "bosh/settings"
	"github.com/cloudfoundry/yagnats"
	"net/url"
)

type mbusHandlerProvider struct {
	settings boshsettings.Service
	logger   boshlog.Logger
	handler  Handler
}

func NewHandlerProvider(settings boshsettings.Service, logger boshlog.Logger) (p mbusHandlerProvider) {
	p.settings = settings
	p.logger = logger
	return
}

func (p mbusHandlerProvider) Get() (handler Handler, err error) {
	if p.handler != nil {
		handler = p.handler
		return
	}

	mbusUrl, err := url.Parse(p.settings.GetMbusUrl())
	if err != nil {
		err = bosherr.WrapError(err, "Parsing handler URL")
		return
	}

	switch mbusUrl.Scheme {
	case "nats":
		handler = newNatsHandler(p.settings, p.logger, yagnats.NewClient())
	case "https":
		handler = newHttpsHandler(mbusUrl, p.logger)
	default:
		err = bosherr.New("Message Bus Handler with scheme %s could not be found", mbusUrl.Scheme)
	}

	p.handler = handler

	return
}
