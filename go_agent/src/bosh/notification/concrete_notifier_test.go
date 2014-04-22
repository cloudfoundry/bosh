package notification_test

import (
	"errors"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	fakembus "bosh/mbus/fakes"
	. "bosh/notification"
)

var _ = Describe("concreteNotifier", func() {
	Describe("NotifyShutdown", func() {
		var (
			handler  *fakembus.FakeHandler
			notifier Notifier
		)

		BeforeEach(func() {
			handler = fakembus.NewFakeHandler()
			notifier = NewNotifier(handler)
		})

		It("sends shutdown message to health manager", func() {
			err := notifier.NotifyShutdown()
			Expect(err).ToNot(HaveOccurred())

			Expect(handler.HMRequests()).To(Equal([]fakembus.HMRequest{
				fakembus.HMRequest{Topic: "shutdown", Payload: nil},
			}))
		})

		It("returns error if sending shutdown message fails", func() {
			handler.SendToHealthManagerErr = errors.New("fake-send-error")

			err := notifier.NotifyShutdown()
			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(ContainSubstring("fake-send-error"))
		})
	})
})
