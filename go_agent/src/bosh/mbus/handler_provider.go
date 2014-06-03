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
	settingsService boshsettings.Service
	logger          boshlog.Logger
	handler         boshhandler.Handler
}

func NewHandlerProvider(
	settingsService boshsettings.Service,
	logger boshlog.Logger,
) (p MbusHandlerProvider) {
	p.settingsService = settingsService
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

	mbusURL, err := url.Parse(p.settingsService.GetSettings().Mbus)
	if err != nil {
		err = bosherr.WrapError(err, "Parsing handler URL")
		return
	}

	switch mbusURL.Scheme {
	case "nats":
		handler = NewNatsHandler(p.settingsService, yagnats.NewClient(), p.logger)
	case "https":
		handler = micro.NewHTTPSHandler(mbusURL, p.logger, platform.GetFs(), dirProvider)
	default:
		err = bosherr.New("Message Bus Handler with scheme %s could not be found", mbusURL.Scheme)
	}

	p.handler = handler

	return
}
