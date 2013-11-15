package action

import (
	boshsettings "bosh/settings"
	"encoding/json"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestGetState(t *testing.T) {
	settings, fs, platform, taskService := getFakeFactoryDependencies()

	fs.WriteToFile(boshsettings.VCAP_BASE_DIR+"/bosh/spec.json", `{"key":"value"}`)
	settings.AgentId = "my-agent-id"
	settings.Vm.Name = "vm-abc-def"

	factory := NewFactory(settings, fs, platform, taskService)

	getStateAction := factory.Create("get_state")

	state, err := getStateAction.Run([]byte(`{"arguments":[]}`))
	assert.NoError(t, err)

	stateBytes, err := json.Marshal(state)
	assert.NoError(t, err)

	expectedJson := map[string]interface{}{
		"agent_id":      "my-agent-id",
		"job_state":     "unknown",
		"bosh_protocol": "1",
		"key":           "value",
		"vm":            map[string]string{"name": "vm-abc-def"},
	}

	expectedBytes, _ := json.Marshal(expectedJson)
	assert.Equal(t, string(expectedBytes), string(stateBytes))
}
