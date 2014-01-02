package agent

import (
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

type agentDeps struct {
	logger           boshlog.Logger
	handler          *fakembus.FakeHandler
	platform         *fakeplatform.FakePlatform
	actionDispatcher *FakeActionDispatcher
}

func buildAgent() (deps agentDeps, agent agent) {
	deps = agentDeps{
		logger:           boshlog.NewLogger(boshlog.LEVEL_NONE),
		handler:          &fakembus.FakeHandler{},
		platform:         fakeplatform.NewFakePlatform(),
		actionDispatcher: &FakeActionDispatcher{},
	}

	agent = New(deps.logger, deps.handler, deps.platform, deps.actionDispatcher)
	return
}
