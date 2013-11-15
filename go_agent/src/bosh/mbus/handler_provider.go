package mbus

import (
	boshsettings "bosh/settings"
	"errors"
	"fmt"
	"github.com/cloudfoundry/yagnats"
	"net/url"
)

type mbusHandlerProvider struct {
	settings boshsettings.Settings
	handlers map[string]Handler
}

func NewHandlerProvider(settings boshsettings.Settings) (p mbusHandlerProvider) {
	p.settings = settings
	p.handlers = map[string]Handler{
		"nats": newNatsHandler(yagnats.NewClient(), settings),
	}
	return
}

func (p mbusHandlerProvider) Get() (handler Handler, err error) {
	mbusUrl, err := url.Parse(p.settings.Mbus)
	if err != nil {
		return
	}

	handler, found := p.handlers[mbusUrl.Scheme]

	if !found {
		err = errors.New(fmt.Sprintf("Message Bus Handler with scheme %s could not be found", mbusUrl.Scheme))
	}
	return
}
