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
	handlers map[string]handlerRunner
}

type handlerRunner interface {
	Handler
	run() (err error)
}

func NewHandlerProvider(settings boshsettings.Service, logger boshlog.Logger, natsClient yagnats.NATSClient) (p mbusHandlerProvider) {
	p.settings = settings
	p.handlers = map[string]handlerRunner{
		"nats": newNatsHandler(settings, logger, natsClient),
	}
	return
}

func (p mbusHandlerProvider) Get() (handler Handler, err error) {
	mbusUrl, err := url.Parse(p.settings.GetMbusUrl())
	if err != nil {
		err = bosherr.WrapError(err, "Parsing handler URL")
		return
	}

	handlerRunner, found := p.handlers[mbusUrl.Scheme]
	handler = handlerRunner

	if !found {
		err = bosherr.New("Message Bus Handler with scheme %s could not be found", mbusUrl.Scheme)
		return
	}

	err = handlerRunner.run()
	if err != nil {
		err = bosherr.WrapError(err, "Running handler")
		return
	}
	return
}
