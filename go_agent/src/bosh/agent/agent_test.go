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
	boshhandler "bosh/handler"
	fakejobsuper "bosh/jobsupervisor/fakes"
	boshlog "bosh/logger"
	boshmbus "bosh/mbus"
	fakembus "bosh/mbus/fakes"
	fakeplatform "bosh/platform/fakes"
	boshvitals "bosh/platform/vitals"
)

type FakeActionDispatcher struct {
	ResumedPreviouslyDispatchedTasks bool

	DispatchReq  boshhandler.Request
	DispatchResp boshhandler.Response
}

func (dispatcher *FakeActionDispatcher) ResumePreviouslyDispatchedTasks() {
	dispatcher.ResumedPreviouslyDispatchedTasks = true
}

func (dispatcher *FakeActionDispatcher) Dispatch(req boshhandler.Request) boshhandler.Response {
	dispatcher.DispatchReq = req
	return dispatcher.DispatchResp
}

func init() {
	Describe("Agent", func() {
		var (
			agent            Agent
			logger           boshlog.Logger
			handler          *fakembus.FakeHandler
			platform         *fakeplatform.FakePlatform
			actionDispatcher *FakeActionDispatcher
			alertBuilder     *fakealert.FakeAlertBuilder
			jobSupervisor    *fakejobsuper.FakeJobSupervisor
			specService      *fakeas.FakeV1Service
		)

		BeforeEach(func() {
			logger = boshlog.NewLogger(boshlog.LevelNone)
			handler = &fakembus.FakeHandler{}
			platform = fakeplatform.NewFakePlatform()
			actionDispatcher = &FakeActionDispatcher{}
			alertBuilder = fakealert.NewFakeAlertBuilder()
			jobSupervisor = fakejobsuper.NewFakeJobSupervisor()
			specService = fakeas.NewFakeV1Service()
			agent = New(logger, handler, platform, actionDispatcher, alertBuilder, jobSupervisor, specService, 5*time.Millisecond)
		})

		Describe("Run", func() {
			It("sets the dispatcher as message handler", func() {
				actionDispatcher.DispatchResp = boshhandler.NewValueResponse("pong")

				err := agent.Run()
				Expect(err).ToNot(HaveOccurred())
				Expect(handler.ReceivedRun).To(BeTrue())

				req := boshhandler.NewRequest("fake-reply", "fake-action", []byte("fake-payload"))
				resp := handler.Func(req)

				Expect(req).To(Equal(actionDispatcher.DispatchReq))
				Expect(actionDispatcher.DispatchResp).To(Equal(resp))
			})

			It("resumes persistent actions *before* dispatching new requests", func() {
				resumedBefore := false
				handler.RunFunc = func() {
					resumedBefore = actionDispatcher.ResumedPreviouslyDispatchedTasks
				}

				err := agent.Run()
				Expect(err).ToNot(HaveOccurred())
				Expect(resumedBefore).To(BeTrue())
			})

			Context("when heartbeats can be sent", func() {
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
					err := agent.Run()
					Expect(err).ToNot(HaveOccurred())

					Expect(handler.InitialHeartbeatSent).To(BeTrue())
					Expect(handler.TickHeartbeatsSent).To(BeFalse())

					Expect(handler.SendToHealthManagerTopic).To(Equal("heartbeat"))
					Expect(handler.SendToHealthManagerPayload.(boshmbus.Heartbeat)).To(Equal(expectedHb))
				})

				It("sends periodic heartbeats", func() {
					err := agent.Run()
					Expect(err).ToNot(HaveOccurred())

					Expect(handler.TickHeartbeatsSent).To(BeFalse())
					time.Sleep(5 * time.Millisecond)
					Expect(handler.TickHeartbeatsSent).To(BeTrue())

					Expect(handler.SendToHealthManagerTopic).To(Equal("heartbeat"))
					Expect(handler.SendToHealthManagerPayload.(boshmbus.Heartbeat)).To(Equal(expectedHb))
				})
			})

			Context("when the agent fails to get job spec for a heartbeat", func() {
				BeforeEach(func() {
					block := make(chan error)
					handler.RunFunc = func() { <-block }
					specService.GetErr = errors.New("fake-spec-service-error")
				})

				It("returns the error", func() {
					err := agent.Run()
					Expect(err).To(HaveOccurred())
					Expect(err.Error()).To(ContainSubstring("fake-spec-service-error"))
				})
			})

			Context("when the agent fails to get vitals for a heartbeat", func() {
				BeforeEach(func() {
					block := make(chan error)
					handler.RunFunc = func() { <-block }
					platform.FakeVitalsService.GetErr = errors.New("fake-vitals-service-error")
				})

				It("returns the error", func() {
					err := agent.Run()
					Expect(err).To(HaveOccurred())
					Expect(err.Error()).To(ContainSubstring("fake-vitals-service-error"))
				})
			})

			It("sets the callback for job failures monitoring", func() {
				builtAlert := boshalert.Alert{ID: "some built alert id"}
				alertBuilder.BuildAlert = builtAlert

				err := agent.Run()
				Expect(err).ToNot(HaveOccurred())
				Expect(handler.SendToHealthManagerTopic).ToNot(Equal("alert"))

				failureAlert := boshalert.MonitAlert{ID: "some random id"}
				jobSupervisor.OnJobFailure(failureAlert)

				Expect(failureAlert).To(Equal(alertBuilder.BuildInput))
				Expect(handler.SendToHealthManagerTopic).To(Equal("alert"))
				Expect(builtAlert).To(Equal(handler.SendToHealthManagerPayload))
			})
		})
	})
}
