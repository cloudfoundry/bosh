package agent_test

import (
	"errors"
	"time"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	. "bosh/agent"
	boshalert "bosh/agent/alert"
	fakealert "bosh/agent/alert/fakes"
	boshas "bosh/agent/applier/applyspec"
	fakeas "bosh/agent/applier/applyspec/fakes"
	fakeagent "bosh/agent/fakes"
	boshhandler "bosh/handler"
	fakejobsuper "bosh/jobsupervisor/fakes"
	boshlog "bosh/logger"
	boshmbus "bosh/mbus"
	fakembus "bosh/mbus/fakes"
	fakeplatform "bosh/platform/fakes"
	boshvitals "bosh/platform/vitals"
	boshsyslog "bosh/syslog"
	fakesyslog "bosh/syslog/fakes"
)

func init() {
	Describe("Agent", func() {
		var (
			logger           boshlog.Logger
			handler          *fakembus.FakeHandler
			platform         *fakeplatform.FakePlatform
			actionDispatcher *fakeagent.FakeActionDispatcher
			alertBuilder     *fakealert.FakeAlertBuilder
			alertSender      *fakeagent.FakeAlertSender
			jobSupervisor    *fakejobsuper.FakeJobSupervisor
			specService      *fakeas.FakeV1Service
			syslogServer     *fakesyslog.FakeServer
			agent            Agent
		)

		BeforeEach(func() {
			logger = boshlog.NewLogger(boshlog.LevelDebug)
			handler = &fakembus.FakeHandler{}
			platform = fakeplatform.NewFakePlatform()
			actionDispatcher = &fakeagent.FakeActionDispatcher{}
			alertBuilder = fakealert.NewFakeAlertBuilder()
			alertSender = &fakeagent.FakeAlertSender{}
			jobSupervisor = fakejobsuper.NewFakeJobSupervisor()
			specService = fakeas.NewFakeV1Service()
			syslogServer = &fakesyslog.FakeServer{}
			agent = New(
				logger,
				handler,
				platform,
				actionDispatcher,
				alertSender,
				jobSupervisor,
				specService,
				syslogServer,
				5*time.Millisecond,
			)
		})

		Describe("Run", func() {
			It("lets dispatcher handle requests arriving via handler", func() {
				err := agent.Run()
				Expect(err).ToNot(HaveOccurred())

				expectedResp := boshhandler.NewValueResponse("pong")
				actionDispatcher.DispatchResp = expectedResp

				req := boshhandler.NewRequest("fake-reply", "fake-action", []byte("fake-payload"))
				resp := handler.RunFunc(req)

				Expect(actionDispatcher.DispatchReq).To(Equal(req))
				Expect(resp).To(Equal(expectedResp))
			})

			It("resumes persistent actions *before* dispatching new requests", func() {
				resumedBeforeStartingToDispatch := false
				handler.RunCallBack = func() {
					resumedBeforeStartingToDispatch = actionDispatcher.ResumedPreviouslyDispatchedTasks
				}

				err := agent.Run()
				Expect(err).ToNot(HaveOccurred())
				Expect(resumedBeforeStartingToDispatch).To(BeTrue())
			})

			Context("when heartbeats can be sent", func() {
				BeforeEach(func() {
					handler.KeepOnRunning()
				})

				BeforeEach(func() {
					jobName := "fake-job"
					jobIndex := 1
					specService.Spec = boshas.V1ApplySpec{
						JobSpec: boshas.JobSpec{Name: &jobName},
						Index:   &jobIndex,
					}

					jobSupervisor.StatusStatus = "fake-state"

					platform.FakeVitalsService.GetVitals = boshvitals.Vitals{
						Load: []string{"a", "b", "c"},
					}
				})

				expectedJobName := "fake-job"
				expectedJobIndex := 1
				expectedHb := boshmbus.Heartbeat{
					Job:      &expectedJobName,
					Index:    &expectedJobIndex,
					JobState: "fake-state",
					Vitals:   boshvitals.Vitals{Load: []string{"a", "b", "c"}},
				}

				It("sends initial heartbeat", func() {
					// Configure periodic heartbeat every 5 hours
					// so that we are sure that we will not receive it
					agent = New(
						logger,
						handler,
						platform,
						actionDispatcher,
						alertSender,
						jobSupervisor,
						specService,
						syslogServer,
						5*time.Hour,
					)

					// Immediately exit after sending initial heartbeat
					handler.SendToHealthManagerErr = errors.New("stop")

					err := agent.Run()
					Expect(err).To(HaveOccurred())
					Expect(err.Error()).To(ContainSubstring("stop"))

					Expect(handler.HMRequests()).To(Equal([]fakembus.HMRequest{
						fakembus.HMRequest{Topic: "heartbeat", Payload: expectedHb},
					}))
				})

				It("sends periodic heartbeats", func() {
					sentRequests := 0
					handler.SendToHealthManagerCallBack = func(_ fakembus.HMRequest) {
						sentRequests++
						if sentRequests == 3 {
							handler.SendToHealthManagerErr = errors.New("stop")
						}
					}

					err := agent.Run()
					Expect(err).To(HaveOccurred())
					Expect(err.Error()).To(ContainSubstring("stop"))

					Expect(handler.HMRequests()).To(Equal([]fakembus.HMRequest{
						fakembus.HMRequest{Topic: "heartbeat", Payload: expectedHb},
						fakembus.HMRequest{Topic: "heartbeat", Payload: expectedHb},
						fakembus.HMRequest{Topic: "heartbeat", Payload: expectedHb},
					}))
				})
			})

			Context("when the agent fails to get job spec for a heartbeat", func() {
				BeforeEach(func() {
					specService.GetErr = errors.New("fake-spec-service-error")
					handler.KeepOnRunning()
				})

				It("returns the error", func() {
					err := agent.Run()
					Expect(err).To(HaveOccurred())
					Expect(err.Error()).To(ContainSubstring("fake-spec-service-error"))
				})
			})

			Context("when the agent fails to get vitals for a heartbeat", func() {
				BeforeEach(func() {
					platform.FakeVitalsService.GetErr = errors.New("fake-vitals-service-error")
					handler.KeepOnRunning()
				})

				It("returns the error", func() {
					err := agent.Run()
					Expect(err).To(HaveOccurred())
					Expect(err.Error()).To(ContainSubstring("fake-vitals-service-error"))
				})
			})

			It("sends job monitoring alerts to health manager", func() {
				handler.KeepOnRunning()

				monitAlert := boshalert.MonitAlert{ID: "fake-monit-alert"}
				jobSupervisor.JobFailureAlert = &monitAlert

				// Immediately exit from Run() after alert is sent
				alertSender.SendAlertErr = errors.New("stop")

				err := agent.Run()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("stop"))

				Expect(alertSender.SendAlertMonitAlert).To(Equal(monitAlert))
			})

			It("sends ssh alerts to health manager", func() {
				handler.KeepOnRunning()

				syslogMsg := boshsyslog.Msg{Content: "fake-content"}
				syslogServer.StartFirstSyslogMsg = &syslogMsg

				// Immediately exit from Run() after alert is sent
				alertSender.SendSSHAlertErr = errors.New("stop")

				err := agent.Run()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("stop"))

				Expect(alertSender.SendSSHAlertMsg).To(Equal(syslogMsg))
			})
		})
	})
}
