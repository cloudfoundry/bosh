package mbus

import (
	"bosh/settings"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestHandlerProviderGetReturnsNatsHandler(t *testing.T) {
	s := settings.Settings{Mbus: "nats://0.0.0.0"}
	provider := NewHandlerProvider(s)
	h, err := provider.Get()

	assert.NoError(t, err)
	assert.IsType(t, natsHandler{}, h)
}

func TestHandlerProviderGetReturnsAnErrorIfNotSupported(t *testing.T) {
	s := settings.Settings{Mbus: "foo://0.0.0.0"}
	provider := NewHandlerProvider(s)
	_, err := provider.Get()

	assert.Error(t, err)
}
