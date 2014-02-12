package notification_test

import (
	fakembus "bosh/mbus/fakes"
	. "bosh/notification"
	"errors"
	. "github.com/onsi/ginkgo"
	"github.com/stretchr/testify/assert"
)

func buildConcreteNotifier() (handler *fakembus.FakeHandler, notifier Notifier) {
	handler = fakembus.NewFakeHandler()
	notifier = NewNotifier(handler)
	return
}
func init() {
	Describe("Testing with Ginkgo", func() {
		It("notify shutdown", func() {
			handler, notifier := buildConcreteNotifier()

			handler.SendToHealthManagerErr = errors.New("fake error")

			err := notifier.NotifyShutdown()
			assert.Equal(GinkgoT(), handler.SendToHealthManagerErr, err)
			assert.Equal(GinkgoT(), "shutdown", handler.SendToHealthManagerTopic)
			assert.Nil(GinkgoT(), handler.SendToHealthManagerPayload)
		})
	})
}
