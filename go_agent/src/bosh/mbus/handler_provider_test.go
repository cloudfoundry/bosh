package mbus

import (
	boshsettings "bosh/settings"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestHandlerProviderGetReturnsNatsHandler(t *testing.T) {
	settings := boshsettings.Settings{Mbus: "nats://0.0.0.0"}
	provider := NewHandlerProvider(settings)
	handler, err := provider.Get()

	assert.NoError(t, err)
	assert.IsType(t, natsHandler{}, handler)
}

func TestHandlerProviderGetReturnsAnErrorIfNotSupported(t *testing.T) {
	settings := boshsettings.Settings{Mbus: "foo://0.0.0.0"}
	provider := NewHandlerProvider(settings)
	_, err := provider.Get()

	assert.Error(t, err)
}
