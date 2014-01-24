package mbus

import (
	bosherr "bosh/errors"
	boshhandler "bosh/handler"
	boshlog "bosh/logger"
	"bosh/micro"
	boshplatform "bosh/platform"
	boshsettings "bosh/settings"
	boshdir "bosh/settings/directories"
	"github.com/cloudfoundry/yagnats"
	"net/url"
)

type mbusHandlerProvider struct {
	settings boshsettings.Service
	logger   boshlog.Logger
	handler  boshhandler.Handler
}

func NewHandlerProvider(settings boshsettings.Service, logger boshlog.Logger) (p mbusHandlerProvider) {
	p.settings = settings
	p.logger = logger
	return
}

func (p mbusHandlerProvider) Get(platform boshplatform.Platform, dirProvider boshdir.DirectoriesProvider) (handler boshhandler.Handler, err error) {
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
		handler = micro.NewHttpsHandler(mbusUrl, p.logger, platform.GetFs(), dirProvider)
	default:
		err = bosherr.New("Message Bus Handler with scheme %s could not be found", mbusUrl.Scheme)
	}

	p.handler = handler

	return
}
