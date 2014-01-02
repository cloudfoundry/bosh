package action

import (
	boshas "bosh/agent/applier/applyspec"
	fakeas "bosh/agent/applier/applyspec/fakes"
	boshassert "bosh/assert"
	fakejobsuper "bosh/jobsupervisor/fakes"
	boshstats "bosh/platform/stats"
	fakestats "bosh/platform/stats/fakes"
	boshsettings "bosh/settings"
	boshdirs "bosh/settings/directories"
	fakesettings "bosh/settings/fakes"
	"errors"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestGetStateShouldBeSynchronous(t *testing.T) {
	settings := &fakesettings.FakeSettingsService{}
	_, _, _, action := buildGetStateAction(settings)
	assert.False(t, action.IsAsynchronous())
}

func TestGetStateRun(t *testing.T) {
	settings := &fakesettings.FakeSettingsService{}
	settings.AgentId = "my-agent-id"
	settings.Vm.Name = "vm-abc-def"

	specService, jobSupervisor, _, action := buildGetStateAction(settings)
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
	boshassert.LacksJsonKey(t, state, "vitals")

	assert.Equal(t, state, expectedSpec)
}

func TestGetStateRunWithoutCurrentSpec(t *testing.T) {
	settings := &fakesettings.FakeSettingsService{}
	settings.AgentId = "my-agent-id"
	settings.Vm.Name = "vm-abc-def"

	specService, jobSupervisor, _, action := buildGetStateAction(settings)
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

	specService, jobSupervisor, _, action := buildGetStateAction(settings)
	jobSupervisor.StatusStatus = "running"

	specService.Spec = boshas.V1ApplySpec{
		Deployment: "fake-deployment",
	}

	expectedVitals := map[string]interface{}{
		"cpu": map[string]int{
			"sys":  10,
			"user": 56,
			"wait": 1,
		},
		"disk": map[string]interface{}{
			"system": map[string]string{
				"percent":       "50",
				"inode_percent": "10",
			},
			"ephemeral": map[string]string{
				"percent":       "75",
				"inode_percent": "20",
			},
			"persistent": map[string]string{
				"percent":       "100",
				"inode_percent": "75",
			},
		},
		"load": []float64{0.2, 4.55, 1.123},
		"mem": map[string]interface{}{
			"kb":      70,
			"percent": 70.0,
		},
		"swap": map[string]interface{}{
			"kb":      600,
			"percent": 60.0,
		},
	}
	expectedVm := map[string]interface{}{"name": "vm-abc-def"}

	state, err := action.Run("full")
	assert.NoError(t, err)

	boshassert.MatchesJsonString(t, state.AgentId, `"my-agent-id"`)
	boshassert.MatchesJsonString(t, state.JobState, `"running"`)
	boshassert.MatchesJsonString(t, state.Deployment, `"fake-deployment"`)
	boshassert.MatchesJsonMap(t, state.Vitals, expectedVitals)
	boshassert.MatchesJsonMap(t, state.Vm, expectedVm)
}

func TestGetStateRunWithFullFormatOptionWhenMissingDisks(t *testing.T) {
	settings := &fakesettings.FakeSettingsService{}
	settings.AgentId = "my-agent-id"
	settings.Vm.Name = "vm-abc-def"

	_, _, statsCollector, action := buildGetStateAction(settings)
	statsCollector.DiskStats = map[string]boshstats.DiskStats{
		"/": boshstats.DiskStats{
			Used:       100,
			Total:      200,
			InodeUsed:  50,
			InodeTotal: 500,
		},
	}

	state, err := action.Run("full")
	assert.NoError(t, err)

	boshassert.LacksJsonKey(t, state.Vitals.Disk, "ephemeral")
	boshassert.LacksJsonKey(t, state.Vitals.Disk, "persistent")
}

func TestGetStateRunWithFullFormatOptionOnSystemDiskError(t *testing.T) {
	settings := &fakesettings.FakeSettingsService{}
	settings.AgentId = "my-agent-id"
	settings.Vm.Name = "vm-abc-def"

	_, _, statsCollector, action := buildGetStateAction(settings)
	statsCollector.DiskStats = map[string]boshstats.DiskStats{}

	_, err := action.Run("full")
	assert.Error(t, err)
}

func buildGetStateAction(settings boshsettings.Service) (
	specService *fakeas.FakeV1Service,
	jobSupervisor *fakejobsuper.FakeJobSupervisor,
	statsCollector *fakestats.FakeStatsCollector,
	action getStateAction,
) {
	jobSupervisor = fakejobsuper.NewFakeJobSupervisor()
	specService = fakeas.NewFakeV1Service()
	dirProvider := boshdirs.NewDirectoriesProvider("/fake/base/dir")
	statsCollector = &fakestats.FakeStatsCollector{
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
		DiskStats: map[string]boshstats.DiskStats{
			"/": boshstats.DiskStats{
				Used:       100,
				Total:      200,
				InodeUsed:  50,
				InodeTotal: 500,
			},
			dirProvider.DataDir(): boshstats.DiskStats{
				Used:       15,
				Total:      20,
				InodeUsed:  10,
				InodeTotal: 50,
			},
			dirProvider.StoreDir(): boshstats.DiskStats{
				Used:       2,
				Total:      2,
				InodeUsed:  3,
				InodeTotal: 4,
			},
		},
	}
	action = newGetState(settings, specService, jobSupervisor, statsCollector, dirProvider)
	return
}
