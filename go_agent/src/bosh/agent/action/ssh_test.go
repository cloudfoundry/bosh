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

func testSSHSetupWithGivenPassword(expectedPwd string) {
	settingsService := &fakesettings.FakeSettingsService{}
	settingsService.Settings.Networks = boshsettings.Networks{
		"fake-net": boshsettings.Network{IP: "ww.xx.yy.zz"},
	}

	platform, action := buildSSHAction(settingsService)

	params := SSHParams{
		User:      "fake-user",
		PublicKey: "fake-public-key",
		Password:  expectedPwd,
	}

	response, err := action.Run("setup", params)
	Expect(err).ToNot(HaveOccurred())
	Expect(response).To(Equal(SSHResult{
		Command: "setup",
		Status:  "success",
		IP:      "ww.xx.yy.zz",
	}))

	Expect(platform.CreateUserUsername).To(Equal("fake-user"))
	Expect(platform.CreateUserPassword).To(Equal(expectedPwd))
	Expect(platform.CreateUserBasePath).To(Equal("/foo/bosh_ssh"))

	Expect(platform.AddUserToGroupsGroups["fake-user"]).To(Equal(
		[]string{boshsettings.VCAPUsername, boshsettings.AdminGroup},
	))

	Expect(platform.SetupSSHPublicKeys["fake-user"]).To(Equal("fake-public-key"))
}

func buildSSHAction(settingsService boshsettings.Service) (*fakeplatform.FakePlatform, SSHAction) {
	platform := fakeplatform.NewFakePlatform()
	dirProvider := boshdirs.NewDirectoriesProvider("/foo")
	action := NewSSH(settingsService, platform, dirProvider)
	return platform, action
}

var _ = Describe("SSHAction", func() {
	var (
		platform        *fakeplatform.FakePlatform
		settingsService boshsettings.Service
		action          SSHAction
	)

	BeforeEach(func() {
		settingsService = &fakesettings.FakeSettingsService{}
		platform, action = buildSSHAction(settingsService)
	})

	It("ssh should be synchronous", func() {
		Expect(action.IsAsynchronous()).To(BeFalse())
	})

	It("is not persistent", func() {
		Expect(action.IsPersistent()).To(BeFalse())
	})

	Describe("Run", func() {
		It("ssh setup without default ip", func() {
			params := SSHParams{
				User:      "some-user",
				Password:  "some-pwd",
				PublicKey: "some-key",
			}

			_, err := action.Run("setup", params)
			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(ContainSubstring("No default ip"))
		})

		It("ssh setup with username and password", func() {
			testSSHSetupWithGivenPassword("some-password")
		})

		It("ssh setup without password", func() {
			testSSHSetupWithGivenPassword("")
		})

		It("ssh run cleanup deletes ephemeral user", func() {
			response, err := action.Run("cleanup", SSHParams{UserRegex: "^foobar.*"})
			Expect(err).ToNot(HaveOccurred())
			Expect(platform.DeleteEphemeralUsersMatchingRegex).To(Equal("^foobar.*"))

			// Make sure empty ip field is not included in the response
			boshassert.MatchesJSONMap(GinkgoT(), response, map[string]interface{}{
				"command": "cleanup",
				"status":  "success",
			})
		})
	})
})
