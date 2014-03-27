package agent_test

import (
	"time"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	. "bosh/agent"
	boshalert "bosh/agent/alert"
	fakealert "bosh/agent/alert/fakes"
	boshhandler "bosh/handler"
	fakejobsup "bosh/jobsupervisor/fakes"
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
			jobSupervisor    *fakejobsup.FakeJobSupervisor
		)

		BeforeEach(func() {
			logger = boshlog.NewLogger(boshlog.LEVEL_NONE)
			handler = &fakembus.FakeHandler{}
			platform = fakeplatform.NewFakePlatform()
			actionDispatcher = &FakeActionDispatcher{}
			alertBuilder = fakealert.NewFakeAlertBuilder()
			jobSupervisor = fakejobsup.NewFakeJobSupervisor()
			agent = New(logger, handler, platform, actionDispatcher, alertBuilder, jobSupervisor, 5*time.Millisecond)
		})

		Describe("Run", func() {
			It("sets the dispatcher as message handler", func() {
				actionDispatcher.DispatchResp = boshhandler.NewValueResponse("pong")

				err := agent.Run()
				Expect(err).ToNot(HaveOccurred())
				Expect(handler.ReceivedRun).To(BeTrue())

				req := boshhandler.NewRequest("reply to me!", "some action", []byte("some payload"))
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

			It("sets up heartbeats", func() {
				platform.FakeVitalsService.GetVitals = boshvitals.Vitals{
					Load: []string{"a", "b", "c"},
				}

				err := agent.Run()
				Expect(err).ToNot(HaveOccurred())
				Expect(handler.TickHeartbeatsSent).To(BeFalse())

				Expect(handler.InitialHeartbeatSent).To(BeTrue())
				Expect(handler.SendToHealthManagerTopic).To(Equal("heartbeat"))
				time.Sleep(5 * time.Millisecond)
				Expect(handler.TickHeartbeatsSent).To(BeTrue())

				hb := handler.SendToHealthManagerPayload.(boshmbus.Heartbeat)
				Expect(hb.Vitals).To(Equal(platform.FakeVitalsService.GetVitals))
			})

			It("sets the callback for job failures monitoring", func() {
				builtAlert := boshalert.Alert{Id: "some built alert id"}
				alertBuilder.BuildAlert = builtAlert

				err := agent.Run()
				Expect(err).ToNot(HaveOccurred())
				Expect(handler.SendToHealthManagerTopic).ToNot(Equal("alert"))

				failureAlert := boshalert.MonitAlert{Id: "some random id"}
				jobSupervisor.OnJobFailure(failureAlert)

				Expect(failureAlert).To(Equal(alertBuilder.BuildInput))
				Expect(handler.SendToHealthManagerTopic).To(Equal("alert"))
				Expect(builtAlert).To(Equal(handler.SendToHealthManagerPayload))
			})
		})
	})
}
