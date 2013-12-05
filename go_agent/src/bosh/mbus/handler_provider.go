package mbus

import (
	bosherr "bosh/errors"
	boshlog "bosh/logger"
	boshsettings "bosh/settings"
	"github.com/cloudfoundry/yagnats"
	"net/url"
)

type mbusHandlerProvider struct {
	settings boshsettings.MbusSettings
	handlers map[string]Handler
}

func NewHandlerProvider(settings boshsettings.MbusSettings, logger boshlog.Logger) (p mbusHandlerProvider) {
	p.settings = settings
	p.handlers = map[string]Handler{
		"nats": newNatsHandler(settings, logger, yagnats.NewClient()),
	}
	return
}

func (p mbusHandlerProvider) Get() (handler Handler, err error) {
	mbusUrl, err := url.Parse(p.settings.GetMbusUrl())
	if err != nil {
		err = bosherr.WrapError(err, "Parsing handler URL")
		return
	}

	handler, found := p.handlers[mbusUrl.Scheme]

	if !found {
		err = bosherr.New("Message Bus Handler with scheme %s could not be found", mbusUrl.Scheme)
	}
	return
}
