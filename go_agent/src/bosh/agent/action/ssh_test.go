package action_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	. "bosh/agent/action"
	boshassert "bosh/assert"
	fakeplatform "bosh/platform/fakes"
	boshsettings "bosh/settings"
	boshdirs "bosh/settings/directories"
	fakesettings "bosh/settings/fakes"
)

func testSshSetupWithGivenPassword(expectedPwd string) {
	settingsService := &fakesettings.FakeSettingsService{}
	settingsService.Settings.Networks = boshsettings.Networks{
		"fake-net": boshsettings.Network{IP: "ww.xx.yy.zz"},
	}

	platform, action := buildSshAction(settingsService)

	params := SshParams{
		User:      "fake-user",
		PublicKey: "fake-public-key",
		Password:  expectedPwd,
	}

	response, err := action.Run("setup", params)
	Expect(err).ToNot(HaveOccurred())
	Expect(response).To(Equal(map[string]string{
		"command": "setup",
		"status":  "success",
		"ip":      "ww.xx.yy.zz",
	}))

	Expect(platform.CreateUserUsername).To(Equal("fake-user"))
	Expect(platform.CreateUserPassword).To(Equal(expectedPwd))
	Expect(platform.CreateUserBasePath).To(Equal("/foo/bosh_ssh"))

	Expect(platform.AddUserToGroupsGroups["fake-user"]).To(Equal(
		[]string{boshsettings.VCAPUsername, boshsettings.AdminGroup},
	))

	Expect(platform.SetupSshPublicKeys["fake-user"]).To(Equal("fake-public-key"))
}

func buildSshAction(settingsService boshsettings.Service) (*fakeplatform.FakePlatform, SshAction) {
	platform := fakeplatform.NewFakePlatform()
	dirProvider := boshdirs.NewDirectoriesProvider("/foo")
	action := NewSsh(settingsService, platform, dirProvider)
	return platform, action
}

func init() {
	Describe("Testing with Ginkgo", func() {
		var (
			settingsService boshsettings.Service
		)

		BeforeEach(func() {
			settingsService = &fakesettings.FakeSettingsService{}
		})

		It("ssh should be synchronous", func() {
			_, action := buildSshAction(settingsService)
			Expect(action.IsAsynchronous()).To(BeFalse())
		})

		It("is not persistent", func() {
			_, action := buildSshAction(settingsService)
			Expect(action.IsPersistent()).To(BeFalse())
		})

		It("ssh setup without default ip", func() {
			_, action := buildSshAction(settingsService)

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
			testSshSetupWithGivenPassword("some-password")
		})

		It("ssh setup without password", func() {
			testSshSetupWithGivenPassword("")
		})

		It("ssh run cleanup deletes ephemeral user", func() {
			platform, action := buildSshAction(settingsService)

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
