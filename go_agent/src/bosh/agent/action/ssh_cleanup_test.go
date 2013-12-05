package action

import (
	boshassert "bosh/assert"
	fakeplatform "bosh/platform/fakes"
	boshsettings "bosh/settings"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestSshRunCleanupDeletesEphemeralUser(t *testing.T) {
	settings := boshsettings.Settings{}
	platform, action := buildSshActionCleanup(settings)

	payload := `{"arguments":["cleanup",{"user_regex":"^foobar.*"}]}`
	response, err := action.Run([]byte(payload))
	assert.NoError(t, err)
	assert.Equal(t, "^foobar.*", platform.DeleteEphemeralUsersMatchingRegex)

	boshassert.MatchesJsonMap(t, response, map[string]interface{}{
		"command": "cleanup",
		"status":  "success",
	})
}

func buildSshActionCleanup(settings boshsettings.Settings) (*fakeplatform.FakePlatform, sshAction) {
	platform := fakeplatform.NewFakePlatform()
	action := newSsh(settings, platform)
	return platform, action
}
