package action

import (
	"encoding/json"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestSshCleanup(t *testing.T) {
	settings, fs, platform, taskService := getFakeFactoryDependencies()
	factory := NewFactory(settings, fs, platform, taskService)
	sshAction := factory.Create("ssh")

	payload := `{"arguments":["cleanup",{"user_regex":"^foobar.*"}]}`

	response, err := sshAction.Run([]byte(payload))
	assert.NoError(t, err)

	// assert on platform interaction
	assert.Equal(t, "^foobar.*", platform.DeleteEphemeralUsersMatchingRegex)

	// assert on the response
	responseBytes, err := json.Marshal(response)
	assert.NoError(t, err)

	expectedJson := map[string]interface{}{
		"command": "cleanup",
		"status":  "success",
	}
	expectedBytes, _ := json.Marshal(expectedJson)
	assert.Equal(t, string(expectedBytes), string(responseBytes))
}
