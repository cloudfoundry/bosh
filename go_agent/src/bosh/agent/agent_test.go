package agent_test

import (
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
	"github.com/stretchr/testify/assert"

	. "github.com/onsi/ginkgo"
	"time"
)

type FakeActionDispatcher struct {
	DispatchReq  boshhandler.Request
	DispatchResp boshhandler.Response
}

func (dispatcher *FakeActionDispatcher) Dispatch(req boshhandler.Request) (resp boshhandler.Response) {
	dispatcher.DispatchReq = req
	resp = dispatcher.DispatchResp
	return
}

type agentDeps struct {
	logger           boshlog.Logger
	handler          *fakembus.FakeHandler
	platform         *fakeplatform.FakePlatform
	actionDispatcher *FakeActionDispatcher
	alertBuilder     *fakealert.FakeAlertBuilder
	jobSupervisor    *fakejobsup.FakeJobSupervisor
}

func buildAgent() (deps agentDeps, agent Agent) {
	deps = agentDeps{
		logger:           boshlog.NewLogger(boshlog.LEVEL_NONE),
		handler:          &fakembus.FakeHandler{},
		platform:         fakeplatform.NewFakePlatform(),
		actionDispatcher: &FakeActionDispatcher{},
		alertBuilder:     fakealert.NewFakeAlertBuilder(),
		jobSupervisor:    fakejobsup.NewFakeJobSupervisor(),
	}

	agent = New(deps.logger, deps.handler, deps.platform, deps.actionDispatcher, deps.alertBuilder, deps.jobSupervisor, 5*time.Millisecond)
	return
}
func init() {
	Describe("Testing with Ginkgo", func() {
		It("run sets the dispatcher as message handler", func() {
			deps, agent := buildAgent()
			deps.actionDispatcher.DispatchResp = boshhandler.NewValueResponse("pong")

			err := agent.Run()

			assert.NoError(GinkgoT(), err)
			assert.True(GinkgoT(), deps.handler.ReceivedRun)

			req := boshhandler.NewRequest("reply to me!", "some action", []byte("some payload"))
			resp := deps.handler.Func(req)

			assert.Equal(GinkgoT(), deps.actionDispatcher.DispatchReq, req)
			assert.Equal(GinkgoT(), resp, deps.actionDispatcher.DispatchResp)
		})
		It("run sets up heartbeats", func() {

			deps, agent := buildAgent()
			deps.platform.FakeVitalsService.GetVitals = boshvitals.Vitals{
				Load: []string{"a", "b", "c"},
			}

			err := agent.Run()
			assert.NoError(GinkgoT(), err)
			assert.False(GinkgoT(), deps.handler.TickHeartbeatsSent)

			assert.True(GinkgoT(), deps.handler.InitialHeartbeatSent)
			assert.Equal(GinkgoT(), "heartbeat", deps.handler.SendToHealthManagerTopic)
			time.Sleep(5 * time.Millisecond)
			assert.True(GinkgoT(), deps.handler.TickHeartbeatsSent)

			hb := deps.handler.SendToHealthManagerPayload.(boshmbus.Heartbeat)
			assert.Equal(GinkgoT(), deps.platform.FakeVitalsService.GetVitals, hb.Vitals)
		})
		It("run sets the callback for job failures monitoring", func() {

			deps, agent := buildAgent()

			builtAlert := boshalert.Alert{Id: "some built alert id"}
			deps.alertBuilder.BuildAlert = builtAlert

			err := agent.Run()
			assert.NoError(GinkgoT(), err)
			assert.NotEqual(GinkgoT(), deps.handler.SendToHealthManagerTopic, "alert")

			failureAlert := boshalert.MonitAlert{Id: "some random id"}
			deps.jobSupervisor.OnJobFailure(failureAlert)

			assert.Equal(GinkgoT(), deps.alertBuilder.BuildInput, failureAlert)
			assert.Equal(GinkgoT(), deps.handler.SendToHealthManagerTopic, "alert")
			assert.Equal(GinkgoT(), deps.handler.SendToHealthManagerPayload, builtAlert)
		})
	})
}
