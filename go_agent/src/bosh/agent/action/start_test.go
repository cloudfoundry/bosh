package action_test

import (
	. "bosh/agent/action"
	fakejobsuper "bosh/jobsupervisor/fakes"
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
	jobSupervisor, action := buildStartAction()

	_, err := action.Run()
	assert.NoError(t, err)
	assert.True(t, jobSupervisor.Started)
}

func buildStartAction() (jobSupervisor *fakejobsuper.FakeJobSupervisor, action StartAction) {
	jobSupervisor = fakejobsuper.NewFakeJobSupervisor()
	action = NewStart(jobSupervisor)
	return
}
