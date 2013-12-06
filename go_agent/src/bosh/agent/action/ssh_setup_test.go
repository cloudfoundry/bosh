package action

import (
	boshassert "bosh/assert"
	fakeplatform "bosh/platform/fakes"
	boshsettings "bosh/settings"
	fakesettings "bosh/settings/fakes"
	"fmt"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestSshSetupWithInvalidPayload(t *testing.T) {
	settings := &fakesettings.FakeSettingsService{}
	_, action := buildSshActionSetup(settings)

	// set user, pwd, public_key with invalid values
	payload := `{"arguments":["setup",{"user":123,"password":456,"public_key":789}]}`
	_, err := action.Run([]byte(payload))
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "Parsing user")
}

func TestSshSetupWithoutDefaultIp(t *testing.T) {
	settings := &fakesettings.FakeSettingsService{}
	_, action := buildSshActionSetup(settings)

	payload := `{"arguments":["setup",{"user":"some-user","password":"some-pwd","public_key":"some-key"}]}`
	_, err := action.Run([]byte(payload))
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

	platform, action := buildSshActionSetup(settings)

	expectedUser := "some-user"
	expectedKey := "some public key content"

	payload := fmt.Sprintf(
		`{"arguments":["setup",{"user":"%s","password":"%s","public_key":"%s"}]}`,
		expectedUser, expectedPwd, expectedKey,
	)

	if expectedPwd == "" {
		payload = fmt.Sprintf(
			`{"arguments":["setup",{"user":"%s","public_key":"%s"}]}`,
			expectedUser, expectedKey,
		)
	}

	boshSshPath := "/var/vcap/bosh_ssh"

	response, err := action.Run([]byte(payload))
	assert.NoError(t, err)

	// assert on user and ssh setup
	assert.Equal(t, expectedUser, platform.CreateUserUsername)
	assert.Equal(t, expectedPwd, platform.CreateUserPassword)
	assert.Equal(t, boshSshPath, platform.CreateUserBasePath)
	assert.Equal(t, []string{boshsettings.VCAP_USERNAME, boshsettings.ADMIN_GROUP}, platform.AddUserToGroupsGroups[expectedUser])
	assert.Equal(t, expectedKey, platform.SetupSshPublicKeys[expectedUser])

	expectedJson := map[string]interface{}{
		"command": "setup",
		"status":  "success",
		"ip":      "ww.xx.yy.zz",
	}

	boshassert.MatchesJsonMap(t, response, expectedJson)
}

func buildSshActionSetup(settings boshsettings.Service) (*fakeplatform.FakePlatform, sshAction) {
	platform := fakeplatform.NewFakePlatform()
	action := newSsh(settings, platform)
	return platform, action
}
