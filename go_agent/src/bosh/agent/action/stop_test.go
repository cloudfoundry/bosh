package action_test

import (
	. "bosh/agent/action"
	fakejobsuper "bosh/jobsupervisor/fakes"
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

func TestStopRunStopsJobSupervisorServices(t *testing.T) {
	jobSupervisor, action := buildStopAction()

	_, err := action.Run()
	assert.NoError(t, err)

	assert.True(t, jobSupervisor.Stopped)
}

func buildStopAction() (jobSupervisor *fakejobsuper.FakeJobSupervisor, action StopAction) {
	jobSupervisor = fakejobsuper.NewFakeJobSupervisor()
	action = NewStop(jobSupervisor)
	return
}
