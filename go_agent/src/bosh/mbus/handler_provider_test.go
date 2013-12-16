package mbus

import (
	boshlog "bosh/logger"
	fakesettings "bosh/settings/fakes"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestHandlerProviderGetReturnsNatsHandler(t *testing.T) {
	settings := &fakesettings.FakeSettingsService{MbusUrl: "nats://0.0.0.0"}

	logger := boshlog.NewLogger(boshlog.LEVEL_NONE)
	provider := NewHandlerProvider(settings, logger)
	handler, err := provider.Get()

	assert.NoError(t, err)
	assert.IsType(t, natsHandler{}, handler)
}

func TestHandlerProviderGetReturnsAnErrorIfNotSupported(t *testing.T) {
	settings := &fakesettings.FakeSettingsService{MbusUrl: "foo://0.0.0.0"}
	logger := boshlog.NewLogger(boshlog.LEVEL_NONE)
	provider := NewHandlerProvider(settings, logger)
	_, err := provider.Get()

	assert.Error(t, err)
}
