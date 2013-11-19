package action

import (
	boshassert "bosh/assert"
	boshsettings "bosh/settings"
	"fmt"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestSshSetupWithInvalidPayload(t *testing.T) {
	settings, fs, platform, blobstore, taskService := getFakeFactoryDependencies()
	factory := NewFactory(settings, fs, platform, blobstore, taskService)
	sshAction := factory.Create("ssh")

	// set user, pwd, public_key with invalid values
	payload := `{"arguments":["setup",{"user":123,"password":456,"public_key":789}]}`

	_, err := sshAction.Run([]byte(payload))
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "Error parsing")
}

func TestSshSetupWithoutDefaultIp(t *testing.T) {
	settings, fs, platform, blobstore, taskService := getFakeFactoryDependencies()
	factory := NewFactory(settings, fs, platform, blobstore, taskService)
	sshAction := factory.Create("ssh")

	payload := `{"arguments":["setup",{"user":"some-user","password":"some-pwd","public_key":"some-key"}]}`

	_, err := sshAction.Run([]byte(payload))
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
	settings, fs, platform, blobstore, taskService := getFakeFactoryDependencies()

	settings.Networks = map[string]boshsettings.NetworkSettings{
		"default": {Ip: "ww.xx.yy.zz"},
	}

	factory := NewFactory(settings, fs, platform, blobstore, taskService)
	sshAction := factory.Create("ssh")

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

	response, err := sshAction.Run([]byte(payload))
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
