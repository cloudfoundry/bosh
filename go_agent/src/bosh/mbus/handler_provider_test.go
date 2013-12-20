package mbus

import (
	boshlog "bosh/logger"
	fakesettings "bosh/settings/fakes"
	"github.com/cloudfoundry/yagnats/fakeyagnats"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestHandlerProviderGetReturnsNatsHandler(t *testing.T) {
	settings, provider := buildProvider()
	settings.MbusUrl = "nats://foo:bar@127.0.0.1:1234"

	handler, err := provider.Get()

	assert.NoError(t, err)
	assert.IsType(t, &natsHandler{}, handler)
}

func TestHandlerProviderGetReturnsAnErrorIfNotSupported(t *testing.T) {
	settings, provider := buildProvider()
	settings.MbusUrl = "foo://127.0.0.1:1234"

	_, err := provider.Get()

	assert.Error(t, err)
}

func buildProvider() (settings *fakesettings.FakeSettingsService, provider mbusHandlerProvider) {
	settings = &fakesettings.FakeSettingsService{MbusUrl: "foo://0.0.0.0"}
	logger := boshlog.NewLogger(boshlog.LEVEL_NONE)
	natsClient := fakeyagnats.New()
	provider = NewHandlerProvider(settings, logger, natsClient)
	return
}
