package agent_test

import (
	"errors"
	"time"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	. "bosh/agent"
	boshalert "bosh/agent/alert"
	fakealert "bosh/agent/alert/fakes"
	fakembus "bosh/mbus/fakes"
	boshsyslog "bosh/syslog"
	faketime "bosh/time/fakes"
	fakeuuid "bosh/uuid/fakes"
)

var _ = Describe("concreteAlertSender", func() {
	var (
		handler       *fakembus.FakeHandler
		alertBuilder  *fakealert.FakeAlertBuilder
		uuidGenerator *fakeuuid.FakeGenerator
		timeService   *faketime.FakeService
		alertSender   AlertSender
	)

	BeforeEach(func() {
		handler = fakembus.NewFakeHandler()
		alertBuilder = fakealert.NewFakeAlertBuilder()
		uuidGenerator = &fakeuuid.FakeGenerator{}
		timeService = &faketime.FakeService{}
		alertSender = NewConcreteAlertSender(handler, alertBuilder, uuidGenerator, timeService)
	})

	Describe("SendAlert", func() {
		monitAlert := boshalert.MonitAlert{ID: "fake-monit-alert"}

		It("sends monit alerts to health manager", func() {
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
			builtAlert := boshalert.Alert{Severity: boshalert.SeverityIgnored}
			alertBuilder.BuildAlert = builtAlert

			err := alertSender.SendAlert(monitAlert)
			Expect(err).ToNot(HaveOccurred())

			Expect(alertBuilder.BuildInput).To(Equal(monitAlert))

			Expect(handler.HMRequests()).To(Equal([]fakembus.HMRequest{}))
		})

		It("returns error if sending alert to health manager fails", func() {
			handler.SendToHealthManagerErr = errors.New("fake-send-to-hm-err")

			err := alertSender.SendAlert(monitAlert)
			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(ContainSubstring("fake-send-to-hm-err"))
		})
	})

	Describe("SendSSHAlert", func() {
		presetNow := time.Now()

		BeforeEach(func() {
			timeService.NowTime = presetNow
			uuidGenerator.GeneratedUuid = "fake-uuid"
		})

		Context("when syslog message indicates ssh login", func() {
			msg := boshsyslog.Msg{Content: "Accepted publickey for tests"}

			It("sends ssh alerts to health manager", func() {
				err := alertSender.SendSSHAlert(msg)
				Expect(err).ToNot(HaveOccurred())

				expectedHMRequest := fakembus.HMRequest{
					Topic: "alert",
					Payload: boshalert.Alert{
						ID:        "fake-uuid",
						Severity:  boshalert.SeverityWarning,
						Title:     "SSH Login",
						Summary:   "Accepted publickey for tests",
						CreatedAt: presetNow.Unix(),
					},
				}

				Expect(handler.HMRequests()).To(Equal([]fakembus.HMRequest{expectedHMRequest}))
			})

			It("returns error if generating uuid fails", func() {
				uuidGenerator.GenerateError = errors.New("fake-generate-err")

				err := alertSender.SendSSHAlert(msg)
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("fake-generate-err"))
			})

			It("returns error if sending alert to health manager fails", func() {
				handler.SendToHealthManagerErr = errors.New("fake-send-to-hm-err")

				err := alertSender.SendSSHAlert(msg)
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("fake-send-to-hm-err"))
			})
		})

		Context("when syslog message indicates ssh logout", func() {
			msg := boshsyslog.Msg{Content: "disconnected by user tests"}

			It("sends ssh alerts to health manager", func() {
				err := alertSender.SendSSHAlert(msg)
				Expect(err).ToNot(HaveOccurred())

				expectedHMRequest := fakembus.HMRequest{
					Topic: "alert",
					Payload: boshalert.Alert{
						ID:        "fake-uuid",
						Severity:  boshalert.SeverityWarning,
						Title:     "SSH Logout",
						Summary:   "disconnected by user tests",
						CreatedAt: presetNow.Unix(),
					},
				}

				Expect(handler.HMRequests()).To(Equal([]fakembus.HMRequest{expectedHMRequest}))
			})

			It("returns error if generating uuid fails", func() {
				uuidGenerator.GenerateError = errors.New("fake-generate-err")

				err := alertSender.SendSSHAlert(msg)
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("fake-generate-err"))
			})

			It("returns error if sending alert to health manager fails", func() {
				handler.SendToHealthManagerErr = errors.New("fake-send-to-hm-err")

				err := alertSender.SendSSHAlert(msg)
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("fake-send-to-hm-err"))
			})
		})

		Context("when syslog message is not ssh related", func() {
			msg := boshsyslog.Msg{Content: "discombobulated by handsome interns"}

			It("does not send any alert to hm", func() {
				err := alertSender.SendSSHAlert(msg)
				Expect(err).ToNot(HaveOccurred())

				Expect(handler.HMRequests()).To(BeEmpty())
			})
		})
	})
})
