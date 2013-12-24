package action

import (
	boshassert "bosh/assert"
	fakeplatform "bosh/platform/fakes"
	boshsettings "bosh/settings"
	boshdirs "bosh/settings/directories"
	fakesettings "bosh/settings/fakes"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestSshShouldBeSynchronous(t *testing.T) {
	settings := &fakesettings.FakeSettingsService{}
	_, action := buildSshAction(settings)
	assert.False(t, action.IsAsynchronous())
}

func TestSshSetupWithoutDefaultIp(t *testing.T) {
	settings := &fakesettings.FakeSettingsService{}
	_, action := buildSshAction(settings)

	params := sshParams{
		User:      "some-user",
		Password:  "some-pwd",
		PublicKey: "some-key",
	}
	_, err := action.Run("setup", params)
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "No default ip")
}

func TestSshSetupWithUsernameAndPassword(t *testing.T) {
	testSshSetupWithGivenPassword(t, "some-password")
}

func TestSshSetupWithoutPassword(t *testing.T) {
	testSshSetupWithGivenPassword(t, "")
}

func testSshSetupWithGivenPassword(t *testing.T, expectedPwd string) {
	settings := &fakesettings.FakeSettingsService{}
	settings.DefaultIp = "ww.xx.yy.zz"

	platform, action := buildSshAction(settings)

	expectedUser := "some-user"
	expectedKey := "some public key content"

	params := sshParams{
		User:      expectedUser,
		PublicKey: expectedKey,
		Password:  expectedPwd,
	}

	response, err := action.Run("setup", params)
	assert.NoError(t, err)

	// assert on user and ssh setup
	assert.Equal(t, expectedUser, platform.CreateUserUsername)
	assert.Equal(t, expectedPwd, platform.CreateUserPassword)
	assert.Equal(t, "/foo/bosh_ssh", platform.CreateUserBasePath)
	assert.Equal(t, []string{boshsettings.VCAP_USERNAME, boshsettings.ADMIN_GROUP}, platform.AddUserToGroupsGroups[expectedUser])
	assert.Equal(t, expectedKey, platform.SetupSshPublicKeys[expectedUser])

	expectedJson := map[string]interface{}{
		"command": "setup",
		"status":  "success",
		"ip":      "ww.xx.yy.zz",
	}

	boshassert.MatchesJsonMap(t, response, expectedJson)
}

func TestSshRunCleanupDeletesEphemeralUser(t *testing.T) {
	settings := &fakesettings.FakeSettingsService{}
	platform, action := buildSshAction(settings)

	params := sshParams{UserRegex: "^foobar.*"}
	response, err := action.Run("cleanup", params)
	assert.NoError(t, err)
	assert.Equal(t, "^foobar.*", platform.DeleteEphemeralUsersMatchingRegex)

	boshassert.MatchesJsonMap(t, response, map[string]interface{}{
		"command": "cleanup",
		"status":  "success",
	})
}

func buildSshAction(settings boshsettings.Service) (*fakeplatform.FakePlatform, sshAction) {
	platform := fakeplatform.NewFakePlatform()
	action := newSsh(settings, platform, boshdirs.NewDirectoriesProvider("/foo"))
	return platform, action
}
