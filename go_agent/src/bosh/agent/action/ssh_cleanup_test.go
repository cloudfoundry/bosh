package action

import (
	boshassert "bosh/assert"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestSshCleanup(t *testing.T) {
	settings, fs, platform, blobstore, taskService := getFakeFactoryDependencies()
	factory := NewFactory(settings, fs, platform, blobstore, taskService)
	sshAction := factory.Create("ssh")

	payload := `{"arguments":["cleanup",{"user_regex":"^foobar.*"}]}`

	response, err := sshAction.Run([]byte(payload))
	assert.NoError(t, err)

	// assert on platform interaction
	assert.Equal(t, "^foobar.*", platform.DeleteEphemeralUsersMatchingRegex)

	// assert on the response

	expectedJson := map[string]interface{}{
		"command": "cleanup",
		"status":  "success",
	}
	boshassert.MatchesJsonMap(t, response, expectedJson)
}
