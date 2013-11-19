package action

import (
	boshassert "bosh/assert"
	boshsettings "bosh/settings"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestGetState(t *testing.T) {
	settings, fs, platform, blobstore, taskService := getFakeFactoryDependencies()

	fs.WriteToFile(boshsettings.VCAP_BASE_DIR+"/bosh/spec.json", `{"key":"value"}`)
	settings.AgentId = "my-agent-id"
	settings.Vm.Name = "vm-abc-def"

	factory := NewFactory(settings, fs, platform, blobstore, taskService)

	getStateAction := factory.Create("get_state")

	state, err := getStateAction.Run([]byte(`{"arguments":[]}`))
	assert.NoError(t, err)

	expectedJson := map[string]interface{}{
		"agent_id":      "my-agent-id",
		"job_state":     "unknown",
		"bosh_protocol": "1",
		"key":           "value",
		"vm":            map[string]string{"name": "vm-abc-def"},
	}

	boshassert.MatchesJsonMap(t, state, expectedJson)
}
