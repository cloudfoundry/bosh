package action

import (
	boshassert "bosh/assert"
	fakemon "bosh/monitor/fakes"
	fakeplatform "bosh/platform/fakes"
	boshsettings "bosh/settings"
	fakesettings "bosh/settings/fakes"
	fakesys "bosh/system/fakes"
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

	fs, monitor, action := buildGetStateAction(settings)
	monitor.StatusStatus = "running"

	fs.WriteToFile(boshsettings.VCAP_BASE_DIR+"/bosh/spec.json", `{"key":"value"}`)

	expectedJson := map[string]interface{}{
		"agent_id":      "my-agent-id",
		"job_state":     "running",
		"bosh_protocol": "1",
		"key":           "value",
		"vm":            map[string]string{"name": "vm-abc-def"},
	}

	state, err := action.Run()
	assert.NoError(t, err)
	boshassert.MatchesJsonMap(t, state, expectedJson)
}

func buildGetStateAction(settings boshsettings.Service) (
	fs *fakesys.FakeFileSystem,
	monitor *fakemon.FakeMonitor,
	action getStateAction) {
	platform := fakeplatform.NewFakePlatform()
	monitor = fakemon.NewFakeMonitor()
	fs = platform.Fs
	action = newGetState(settings, platform.Fs, monitor)
	return
}
