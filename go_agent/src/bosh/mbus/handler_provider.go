package mbus

import (
	"net/url"

	"github.com/cloudfoundry/yagnats"

	bosherr "bosh/errors"
	boshhandler "bosh/handler"
	boshlog "bosh/logger"
	"bosh/micro"
	boshplatform "bosh/platform"
	boshsettings "bosh/settings"
	boshdir "bosh/settings/directories"
)

type MbusHandlerProvider struct {
	settings boshsettings.Service
	logger   boshlog.Logger
	handler  boshhandler.Handler
}

func NewHandlerProvider(settings boshsettings.Service, logger boshlog.Logger) (p MbusHandlerProvider) {
	p.settings = settings
	p.logger = logger
	return
}

func (p MbusHandlerProvider) Get(
	platform boshplatform.Platform,
	dirProvider boshdir.DirectoriesProvider,
) (handler boshhandler.Handler, err error) {
	if p.handler != nil {
		handler = p.handler
		return
	}

	mbusURL, err := url.Parse(p.settings.GetMbusURL())
	if err != nil {
		err = bosherr.WrapError(err, "Parsing handler URL")
		return
	}

	switch mbusURL.Scheme {
	case "nats":
		handler = NewNatsHandler(p.settings, p.logger, yagnats.NewClient())
	case "https":
		handler = micro.NewHTTPSHandler(mbusURL, p.logger, platform.GetFs(), dirProvider)
	default:
		err = bosherr.New("Message Bus Handler with scheme %s could not be found", mbusURL.Scheme)
	}

	p.handler = handler

	return
}
