package action

import (
	boshas "bosh/agent/applier/applyspec"
	fakeas "bosh/agent/applier/applyspec/fakes"
	boshassert "bosh/assert"
	fakejobsuper "bosh/jobsupervisor/fakes"
	boshntp "bosh/platform/ntp"
	fakentp "bosh/platform/ntp/fakes"
	boshvitals "bosh/platform/vitals"
	fakevitals "bosh/platform/vitals/fakes"
	boshsettings "bosh/settings"
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
		Ntp: boshntp.NTPInfo{
			Offset:    "0.34958",
			Timestamp: "12 Oct 17:37:58",
		},
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
		Ntp: boshntp.NTPInfo{
			Offset:    "0.34958",
			Timestamp: "12 Oct 17:37:58",
		},
	}

	state, err := action.Run()
	assert.NoError(t, err)
	boshassert.MatchesJsonMap(t, expectedSpec.Ntp, map[string]interface{}{
		"offset":    "0.34958",
		"timestamp": "12 Oct 17:37:58",
	})
	assert.Equal(t, state, expectedSpec)
}

func TestGetStateRunWithFullFormatOption(t *testing.T) {
	settings := &fakesettings.FakeSettingsService{}
	settings.AgentId = "my-agent-id"
	settings.Vm.Name = "vm-abc-def"

	specService, jobSupervisor, fakeVitals, action := buildGetStateAction(settings)
	jobSupervisor.StatusStatus = "running"

	specService.Spec = boshas.V1ApplySpec{
		Deployment: "fake-deployment",
	}

	expectedVitals := boshvitals.Vitals{
		Load: []string{"foo", "bar", "baz"},
	}
	fakeVitals.GetVitals = expectedVitals
	expectedVm := map[string]interface{}{"name": "vm-abc-def"}

	state, err := action.Run("full")
	assert.NoError(t, err)

	boshassert.MatchesJsonString(t, state.AgentId, `"my-agent-id"`)
	boshassert.MatchesJsonString(t, state.JobState, `"running"`)
	boshassert.MatchesJsonString(t, state.Deployment, `"fake-deployment"`)
	assert.Equal(t, *state.Vitals, expectedVitals)
	boshassert.MatchesJsonMap(t, state.Vm, expectedVm)
}

func TestGetStateRunOnVitalsError(t *testing.T) {
	settings := &fakesettings.FakeSettingsService{}

	_, _, fakeVitals, action := buildGetStateAction(settings)
	fakeVitals.GetErr = errors.New("Oops, could not get vitals")

	_, err := action.Run("full")
	assert.Error(t, err)
}

func buildGetStateAction(settings boshsettings.Service) (
	specService *fakeas.FakeV1Service,
	jobSupervisor *fakejobsuper.FakeJobSupervisor,
	vitalsService *fakevitals.FakeService,
	action getStateAction,
) {
	jobSupervisor = fakejobsuper.NewFakeJobSupervisor()
	specService = fakeas.NewFakeV1Service()
	vitalsService = fakevitals.NewFakeService()
	fakeNTPService := &fakentp.FakeService{
		GetOffsetNTPOffset: boshntp.NTPInfo{
			Offset:    "0.34958",
			Timestamp: "12 Oct 17:37:58",
		},
	}
	action = newGetState(settings, specService, jobSupervisor, vitalsService, fakeNTPService)
	return
}
