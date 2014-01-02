package action

import (
	boshas "bosh/agent/applier/applyspec"
	fakeas "bosh/agent/applier/applyspec/fakes"
	fakejobsuper "bosh/jobsupervisor/fakes"
	boshstats "bosh/platform/stats"
	fakestats "bosh/platform/stats/fakes"
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

	specService, jobSupervisor, action := buildGetStateAction(settings)
	jobSupervisor.StatusStatus = "running"

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

	specService, jobSupervisor, action := buildGetStateAction(settings)
	jobSupervisor.StatusStatus = "running"

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

func TestGetStateRunWithFullFormatOption(t *testing.T) {
	settings := &fakesettings.FakeSettingsService{}
	settings.AgentId = "my-agent-id"
	settings.Vm.Name = "vm-abc-def"

	specService, jobSupervisor, action := buildGetStateAction(settings)
	jobSupervisor.StatusStatus = "running"

	specService.Spec = boshas.V1ApplySpec{
		Deployment: "fake-deployment",
	}

	expectedSpec := getStateV1ApplySpec{
		AgentId:      "my-agent-id",
		JobState:     "running",
		BoshProtocol: "1",
		Vm:           boshsettings.Vm{Name: "vm-abc-def"},
		Vitals: getStateV1Vitals{
			Load: []float64{0.2, 4.55, 1.123},
			CPU: getStateV1VitalsCPU{
				User: 56,
				Sys:  10,
				Wait: 1,
			},
			Mem: getStateV1VitalsMemory{
				Percent: 70.0,
				Kb:      70,
			},
			Swap: getStateV1VitalsMemory{
				Percent: 60.0,
				Kb:      600,
			},
		},
	}
	expectedSpec.Deployment = "fake-deployment"

	state, err := action.Run("full")
	assert.NoError(t, err)

	assert.Equal(t, state.AgentId, expectedSpec.AgentId)
	assert.Equal(t, state.JobState, expectedSpec.JobState)
	assert.Equal(t, state.Deployment, expectedSpec.Deployment)

	assert.Equal(t, state.Vitals.Load, expectedSpec.Vitals.Load)
	assert.Equal(t, state.Vitals.CPU, expectedSpec.Vitals.CPU)
	assert.Equal(t, state.Vitals.Mem, expectedSpec.Vitals.Mem)
	assert.Equal(t, state.Vitals.Swap, expectedSpec.Vitals.Swap)

	assert.Equal(t, state, expectedSpec)
}

func buildGetStateAction(settings boshsettings.Service) (
	specService *fakeas.FakeV1Service,
	jobSupervisor *fakejobsuper.FakeJobSupervisor,
	action getStateAction,
) {
	jobSupervisor = fakejobsuper.NewFakeJobSupervisor()
	specService = fakeas.NewFakeV1Service()
	statsCollector := &fakestats.FakeStatsCollector{
		CpuLoad: boshstats.CpuLoad{
			One:     0.2,
			Five:    4.55,
			Fifteen: 1.123,
		},
		CpuStats: boshstats.CpuStats{
			User:  56,
			Sys:   10,
			Wait:  1,
			Total: 67,
		},
		MemStats: boshstats.MemStats{
			Used:  70,
			Total: 100,
		},
		SwapStats: boshstats.MemStats{
			Used:  600,
			Total: 1000,
		},
	}
	action = newGetState(settings, specService, jobSupervisor, statsCollector)
	return
}
