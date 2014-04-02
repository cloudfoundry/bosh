package notification_test

import (
	"errors"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
	"github.com/stretchr/testify/assert"

	fakembus "bosh/mbus/fakes"
	. "bosh/notification"
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
			Expect(handler.SendToHealthManagerErr).To(Equal(err))
			Expect("shutdown").To(Equal(handler.SendToHealthManagerTopic))
			assert.Nil(GinkgoT(), handler.SendToHealthManagerPayload)
		})
	})
}
