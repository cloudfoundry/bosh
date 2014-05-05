package agent_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	. "bosh/agent"
	boshalert "bosh/agent/alert"
	fakealert "bosh/agent/alert/fakes"
	fakembus "bosh/mbus/fakes"
)

var _ = Describe("Agent", func() {
	var (
		handler      *fakembus.FakeHandler
		alertBuilder *fakealert.FakeAlertBuilder
		alertSender  AlertSender
	)

	BeforeEach(func() {
		handler = fakembus.NewFakeHandler()
		alertBuilder = fakealert.NewFakeAlertBuilder()
		alertSender = NewAlertSender(handler, alertBuilder)
	})

	Describe("SendAlert", func() {
		It("sends monit alerts to health manager", func() {
			monitAlert := boshalert.MonitAlert{ID: "fake-monit-alert"}

			builtAlert := boshalert.Alert{ID: "fake-built-alert"}
			alertBuilder.BuildAlert = builtAlert

			err := alertSender.SendAlert(monitAlert)
			Expect(err).ToNot(HaveOccurred())

			Expect(alertBuilder.BuildInput).To(Equal(monitAlert))

			Expect(handler.HMRequests()).To(Equal([]fakembus.HMRequest{
				fakembus.HMRequest{Topic: "alert", Payload: builtAlert},
			}))
		})

		It("does not send monit alerts with severity=ignored to health manager", func() {
			monitAlert := boshalert.MonitAlert{ID: "fake-monit-alert"}

			builtAlert := boshalert.Alert{Severity: boshalert.SeverityIgnored}
			alertBuilder.BuildAlert = builtAlert

			err := alertSender.SendAlert(monitAlert)
			Expect(err).ToNot(HaveOccurred())

			Expect(alertBuilder.BuildInput).To(Equal(monitAlert))

			Expect(handler.HMRequests()).To(Equal([]fakembus.HMRequest{}))
		})
	})
})
