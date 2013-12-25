package action

import (
	fakemon "bosh/monitor/fakes"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestStartShouldBeSynchronous(t *testing.T) {
	_, action := buildStartAction()
	assert.False(t, action.IsAsynchronous())
}

func TestStartRunReturnsStarted(t *testing.T) {
	_, action := buildStartAction()

	started, err := action.Run()
	assert.NoError(t, err)
	assert.Equal(t, "started", started)
}

func TestStartRunStartsMonitorServices(t *testing.T) {
	monitor, action := buildStartAction()

	_, err := action.Run()
	assert.NoError(t, err)
	assert.True(t, monitor.Started)
}

func buildStartAction() (monitor *fakemon.FakeMonitor, action startAction) {
	monitor = fakemon.NewFakeMonitor()
	action = newStart(monitor)
	return
}
