package agent

import (
	"bosh/mbus"
	testmbus "bosh/mbus/testhelpers"
	"github.com/stretchr/testify/assert"
	"testing"
	"time"
)

func TestRunHandlesAMessage(t *testing.T) {
	req := mbus.Request{Method: "ping"}
	expectedResp := mbus.Response{Value: "pong"}

	assertResponseForRequest(t, req, expectedResp)
}

func assertResponseForRequest(t *testing.T, req mbus.Request, expectedResp mbus.Response) {
	handler := &testmbus.FakeHandler{}
	agent := New(handler)
	err := agent.Run()
	assert.NoError(t, err)
	assert.True(t, handler.ReceivedRun)

	resp := handler.Func(req)

	assert.Equal(t, resp, expectedResp)
}

func TestRunSetsUpHeartbeats(t *testing.T) {
	handler := &testmbus.FakeHandler{}
	agent := New(handler)
	agent.heartbeatInterval = time.Millisecond
	err := agent.Run()
	assert.NoError(t, err)

	hb := <-handler.HeartbeatChan
	assert.IsType(t, mbus.Heartbeat{}, hb)
}
