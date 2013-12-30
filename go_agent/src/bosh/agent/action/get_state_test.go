package action

import (
	boshas "bosh/agent/applier/applyspec"
	fakeas "bosh/agent/applier/applyspec/fakes"
	fakemon "bosh/monitor/fakes"
	boshsettings "bosh/settings"
	fakesettings "bosh/settings/fakes"
	"errors"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestGetStateShouldBeSynchronous(t *testing.T) {
	settings := &fakesettings.FakeSettingsService{}
	_, _, action := buildGetStateAction(settings)
	assert.False(t, action.IsAsynchronous())
}

func TestGetStateRun(t *testing.T) {
	settings := &fakesettings.FakeSettingsService{}
	settings.AgentId = "my-agent-id"
	settings.Vm.Name = "vm-abc-def"

	specService, monitor, action := buildGetStateAction(settings)
	monitor.StatusStatus = "running"

	specService.Spec = boshas.V1ApplySpec{
		Deployment: "fake-deployment",
	}

	expectedSpec := getStateV1ApplySpec{
		AgentId:      "my-agent-id",
		JobState:     "running",
		BoshProtocol: "1",
		Vm:           boshsettings.Vm{Name: "vm-abc-def"},
	}
	expectedSpec.Deployment = "fake-deployment"

	state, err := action.Run()
	assert.NoError(t, err)

	assert.Equal(t, state.AgentId, expectedSpec.AgentId)
	assert.Equal(t, state.JobState, expectedSpec.JobState)
	assert.Equal(t, state.Deployment, expectedSpec.Deployment)

	assert.Equal(t, state, expectedSpec)
}

func TestGetStateRunWithoutCurrentSpec(t *testing.T) {
	settings := &fakesettings.FakeSettingsService{}
	settings.AgentId = "my-agent-id"
	settings.Vm.Name = "vm-abc-def"

	specService, monitor, action := buildGetStateAction(settings)
	monitor.StatusStatus = "running"

	specService.GetErr = errors.New("some error")
	specService.Spec = boshas.V1ApplySpec{
		Deployment: "fake-deployment",
	}

	expectedSpec := getStateV1ApplySpec{
		AgentId:      "my-agent-id",
		JobState:     "running",
		BoshProtocol: "1",
		Vm:           boshsettings.Vm{Name: "vm-abc-def"},
	}

	state, err := action.Run()
	assert.NoError(t, err)
	assert.Equal(t, state, expectedSpec)
}

func buildGetStateAction(settings boshsettings.Service) (
	specService *fakeas.FakeV1Service,
	monitor *fakemon.FakeMonitor,
	action getStateAction,
) {
	monitor = fakemon.NewFakeMonitor()
	specService = fakeas.NewFakeV1Service()
	action = newGetState(settings, specService, monitor)
	return
}
