package action

import (
	fakemon "bosh/monitor/fakes"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestStopShouldBeAsynchronous(t *testing.T) {
	_, action := buildStopAction()
	assert.True(t, action.IsAsynchronous())
}

func TestStopRunReturnsStopped(t *testing.T) {
	_, action := buildStopAction()
	stopped, err := action.Run()
	assert.NoError(t, err)
	assert.Equal(t, "stopped", stopped)
}

func TestStopRunStopsMonitorServices(t *testing.T) {
	monitor, action := buildStopAction()

	_, err := action.Run()
	assert.NoError(t, err)

	assert.True(t, monitor.Stopped)
}

func buildStopAction() (monitor *fakemon.FakeMonitor, action stopAction) {
	monitor = fakemon.NewFakeMonitor()
	action = newStop(monitor)
	return
}
