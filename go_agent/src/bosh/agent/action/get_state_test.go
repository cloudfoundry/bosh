package action

import (
	boshassert "bosh/assert"
	fakeplatform "bosh/platform/fakes"
	boshsettings "bosh/settings"
	boshsys "bosh/system"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestGetStateRun(t *testing.T) {
	settings := boshsettings.Settings{}
	settings.AgentId = "my-agent-id"
	settings.Vm.Name = "vm-abc-def"

	fs, action := buildGetStateAction(settings)

	fs.WriteToFile(boshsettings.VCAP_BASE_DIR+"/bosh/spec.json", `{"key":"value"}`)

	expectedJson := map[string]interface{}{
		"agent_id":      "my-agent-id",
		"job_state":     "unknown",
		"bosh_protocol": "1",
		"key":           "value",
		"vm":            map[string]string{"name": "vm-abc-def"},
	}

	state, err := action.Run([]byte(`{"arguments":[]}`))
	assert.NoError(t, err)
	boshassert.MatchesJsonMap(t, state, expectedJson)
}

func buildGetStateAction(settings boshsettings.Settings) (boshsys.FileSystem, getStateAction) {
	platform := fakeplatform.NewFakePlatform()
	return platform.Fs, newGetState(settings, platform.Fs)
}
