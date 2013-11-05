package mbus

import (
	"bosh/settings"
	"errors"
	"fmt"
	"github.com/cloudfoundry/yagnats"
	"net/url"
)

type mbusHandlerProvider struct {
	settings settings.Settings
	handlers map[string]Handler
}

func NewHandlerProvider(s settings.Settings) (p mbusHandlerProvider) {
	p.settings = s
	p.handlers = map[string]Handler{
		"nats": newNatsHandler(yagnats.NewClient(), s),
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
