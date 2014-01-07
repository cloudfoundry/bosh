package agent

import (
	boshalert "bosh/agent/alert"
	fakealert "bosh/agent/alert/fakes"
	fakejobsup "bosh/jobsupervisor/fakes"
	boshlog "bosh/logger"
	boshmbus "bosh/mbus"
	fakembus "bosh/mbus/fakes"
	fakeplatform "bosh/platform/fakes"
	boshvitals "bosh/platform/vitals"
	"github.com/stretchr/testify/assert"
	"testing"
	"time"
)

type FakeActionDispatcher struct {
	DispatchReq  boshmbus.Request
	DispatchResp boshmbus.Response
}

func (dispatcher *FakeActionDispatcher) Dispatch(req boshmbus.Request) (resp boshmbus.Response) {
	dispatcher.DispatchReq = req
	resp = dispatcher.DispatchResp
	return
}

func TestRunSetsTheDispatcherAsMessageHandler(t *testing.T) {
	deps, agent := buildAgent()
	deps.actionDispatcher.DispatchResp = boshmbus.NewValueResponse("pong")

	err := agent.Run()

	assert.NoError(t, err)
	assert.True(t, deps.handler.ReceivedRun)

	req := boshmbus.NewRequest("reply to me!", "some action", []byte("some payload"))
	resp := deps.handler.Func(req)

	assert.Equal(t, deps.actionDispatcher.DispatchReq, req)
	assert.Equal(t, resp, deps.actionDispatcher.DispatchResp)
}

func TestRunSetsUpHeartbeats(t *testing.T) {
	deps, agent := buildAgent()
	deps.platform.FakeVitalsService.GetVitals = boshvitals.Vitals{
		Load: []string{"a", "b", "c"},
	}

	agent.heartbeatInterval = 5 * time.Millisecond
	err := agent.Run()
	assert.NoError(t, err)
	assert.False(t, deps.handler.TickHeartbeatsSent)

	assert.True(t, deps.handler.InitialHeartbeatSent)
	assert.Equal(t, "heartbeat", deps.handler.SendToHealthManagerTopic)
	time.Sleep(5 * time.Millisecond)
	assert.True(t, deps.handler.TickHeartbeatsSent)

	hb := deps.handler.SendToHealthManagerPayload.(boshmbus.Heartbeat)
	assert.Equal(t, deps.platform.FakeVitalsService.GetVitals, hb.Vitals)
}

func TestRunSetsTheCallbackForJobFailuresMonitoring(t *testing.T) {
	deps, agent := buildAgent()

	builtAlert := boshalert.Alert{Id: "some built alert id"}
	deps.alertBuilder.BuildAlert = builtAlert

	err := agent.Run()
	assert.NoError(t, err)
	assert.NotEqual(t, deps.handler.SendToHealthManagerTopic, "alert")

	failureAlert := boshalert.MonitAlert{Id: "some random id"}
	deps.jobSupervisor.OnJobFailure(failureAlert)

	assert.Equal(t, deps.alertBuilder.BuildInput, failureAlert)
	assert.Equal(t, deps.handler.SendToHealthManagerTopic, "alert")
	assert.Equal(t, deps.handler.SendToHealthManagerPayload, builtAlert)
}

type agentDeps struct {
	logger           boshlog.Logger
	handler          *fakembus.FakeHandler
	platform         *fakeplatform.FakePlatform
	actionDispatcher *FakeActionDispatcher
	alertBuilder     *fakealert.FakeAlertBuilder
	jobSupervisor    *fakejobsup.FakeJobSupervisor
}

func buildAgent() (deps agentDeps, agent agent) {
	deps = agentDeps{
		logger:           boshlog.NewLogger(boshlog.LEVEL_NONE),
		handler:          &fakembus.FakeHandler{},
		platform:         fakeplatform.NewFakePlatform(),
		actionDispatcher: &FakeActionDispatcher{},
		alertBuilder:     fakealert.NewFakeAlertBuilder(),
		jobSupervisor:    fakejobsup.NewFakeJobSupervisor(),
	}

	agent = New(deps.logger, deps.handler, deps.platform, deps.actionDispatcher, deps.alertBuilder, deps.jobSupervisor)
	return
}
