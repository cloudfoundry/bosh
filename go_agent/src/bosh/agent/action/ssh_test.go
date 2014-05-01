package action_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
	"github.com/stretchr/testify/assert"

	. "bosh/agent/action"
	boshassert "bosh/assert"
	fakeplatform "bosh/platform/fakes"
	boshsettings "bosh/settings"
	boshdirs "bosh/settings/directories"
	fakesettings "bosh/settings/fakes"
)

func testSshSetupWithGivenPassword(t assert.TestingT, expectedPwd string) {
	settings := &fakesettings.FakeSettingsService{}
	settings.DefaultIP = "ww.xx.yy.zz"

	platform, action := buildSshAction(settings)

	expectedUser := "some-user"
	expectedKey := "some public key content"

	params := SshParams{
		User:      expectedUser,
		PublicKey: expectedKey,
		Password:  expectedPwd,
	}

	response, err := action.Run("setup", params)
	assert.NoError(t, err)

	assert.Equal(t, expectedUser, platform.CreateUserUsername)
	assert.Equal(t, expectedPwd, platform.CreateUserPassword)
	assert.Equal(t, "/foo/bosh_ssh", platform.CreateUserBasePath)
	assert.Equal(t, []string{boshsettings.VCAPUsername, boshsettings.AdminGroup}, platform.AddUserToGroupsGroups[expectedUser])
	assert.Equal(t, expectedKey, platform.SetupSshPublicKeys[expectedUser])

	expectedJSON := map[string]interface{}{
		"command": "setup",
		"status":  "success",
		"ip":      "ww.xx.yy.zz",
	}

	boshassert.MatchesJSONMap(t, response, expectedJSON)
}

func buildSshAction(settings boshsettings.Service) (*fakeplatform.FakePlatform, SshAction) {
	platform := fakeplatform.NewFakePlatform()
	action := NewSsh(settings, platform, boshdirs.NewDirectoriesProvider("/foo"))
	return platform, action
}
func init() {
	Describe("Testing with Ginkgo", func() {
		It("ssh should be synchronous", func() {
			settings := &fakesettings.FakeSettingsService{}
			_, action := buildSshAction(settings)
			Expect(action.IsAsynchronous()).To(BeFalse())
		})

		It("is not persistent", func() {
			settings := &fakesettings.FakeSettingsService{}
			_, action := buildSshAction(settings)
			Expect(action.IsPersistent()).To(BeFalse())
		})

		It("ssh setup without default ip", func() {

			settings := &fakesettings.FakeSettingsService{}
			_, action := buildSshAction(settings)

			params := SshParams{
				User:      "some-user",
				Password:  "some-pwd",
				PublicKey: "some-key",
			}
			_, err := action.Run("setup", params)
			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(ContainSubstring("No default ip"))
		})
		It("ssh setup with username and password", func() {

			testSshSetupWithGivenPassword(GinkgoT(), "some-password")
		})
		It("ssh setup without password", func() {

			testSshSetupWithGivenPassword(GinkgoT(), "")
		})
		It("ssh run cleanup deletes ephemeral user", func() {

			settings := &fakesettings.FakeSettingsService{}
			platform, action := buildSshAction(settings)

			params := SshParams{UserRegex: "^foobar.*"}
			response, err := action.Run("cleanup", params)
			Expect(err).ToNot(HaveOccurred())
			Expect("^foobar.*").To(Equal(platform.DeleteEphemeralUsersMatchingRegex))

			boshassert.MatchesJSONMap(GinkgoT(), response, map[string]interface{}{
				"command": "cleanup",
				"status":  "success",
			})
		})
	})
}
