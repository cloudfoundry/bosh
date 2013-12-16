package action

import (
	boshassert "bosh/assert"
	fakeplatform "bosh/platform/fakes"
	fakesettings "bosh/settings/fakes"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestSshRunCleanupDeletesEphemeralUser(t *testing.T) {
	platform, action := buildSshActionCleanup()

	payload := `{"arguments":["cleanup",{"user_regex":"^foobar.*"}]}`
	response, err := action.Run([]byte(payload))
	assert.NoError(t, err)
	assert.Equal(t, "^foobar.*", platform.DeleteEphemeralUsersMatchingRegex)

	boshassert.MatchesJsonMap(t, response, map[string]interface{}{
		"command": "cleanup",
		"status":  "success",
	})
}

func buildSshActionCleanup() (*fakeplatform.FakePlatform, sshAction) {
	platform := fakeplatform.NewFakePlatform()
	settings := &fakesettings.FakeSettingsService{}
	action := newSsh(settings, platform)
	return platform, action
}
