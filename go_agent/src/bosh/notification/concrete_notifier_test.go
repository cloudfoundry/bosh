package notification

import (
	fakembus "bosh/mbus/fakes"
	"errors"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestNotifyShutdown(t *testing.T) {
	handler, notifier := buildConcreteNotifier()

	handler.NotifyShutdownErr = errors.New("fake error")

	err := notifier.NotifyShutdown()
	assert.Equal(t, handler.NotifyShutdownErr, err)
	assert.True(t, handler.NotifiedShutdown)
}

func buildConcreteNotifier() (handler *fakembus.FakeHandler, notifier Notifier) {
	handler = fakembus.NewFakeHandler()
	notifier = NewNotifier(handler)
	return
}
