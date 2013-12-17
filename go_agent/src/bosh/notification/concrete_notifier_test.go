package notification

import (
	fakembus "bosh/mbus/fakes"
	"errors"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestNotifyShutdown(t *testing.T) {
	handler, notifier := buildConcreteNotifier()

	handler.SendToHealthManagerErr = errors.New("fake error")

	err := notifier.NotifyShutdown()
	assert.Equal(t, handler.SendToHealthManagerErr, err)
	assert.Equal(t, "shutdown", handler.SendToHealthManagerTopic)
	assert.Nil(t, handler.SendToHealthManagerPayload)
}

func buildConcreteNotifier() (handler *fakembus.FakeHandler, notifier Notifier) {
	handler = fakembus.NewFakeHandler()
	notifier = NewNotifier(handler)
	return
}
