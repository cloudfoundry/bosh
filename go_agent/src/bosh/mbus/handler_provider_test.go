package mbus

import (
	boshlog "bosh/logger"
	fakesettings "bosh/settings/fakes"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestHandlerProviderGetReturnsNatsHandler(t *testing.T) {
	provider := buildProvider("nats://0.0.0.0")
	handler, err := provider.Get()

	assert.NoError(t, err)
	assert.IsType(t, natsHandler{}, handler)
}

func TestHandlerProviderGetReturnsHttpsHandler(t *testing.T) {
	provider := buildProvider("https://0.0.0.0")
	handler, err := provider.Get()

	assert.NoError(t, err)
	assert.IsType(t, httpsHandler{}, handler)
}

func TestHandlerProviderGetReturnsAnErrorIfNotSupported(t *testing.T) {
	provider := buildProvider("foo://0.0.0.0")
	_, err := provider.Get()

	assert.Error(t, err)
}

func buildProvider(mbusUrl string) (provider mbusHandlerProvider) {
	settings := &fakesettings.FakeSettingsService{MbusUrl: mbusUrl}
	logger := boshlog.NewLogger(boshlog.LEVEL_NONE)
	provider = NewHandlerProvider(settings, logger)
	return
}
