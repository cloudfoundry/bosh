package action_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	. "bosh/agent/action"
	boshassert "bosh/assert"
	boshlog "bosh/logger"
	fakeplatform "bosh/platform/fakes"
	boshsettings "bosh/settings"
	fakesettings "bosh/settings/fakes"
)

func init() {
	Describe("ListDisk", func() {
		var (
			settingsService *fakesettings.FakeSettingsService
			platform        *fakeplatform.FakePlatform
			logger          boshlog.Logger
			action          ListDiskAction
		)

		BeforeEach(func() {
			settingsService = &fakesettings.FakeSettingsService{}
			platform = fakeplatform.NewFakePlatform()
			logger = boshlog.NewLogger(boshlog.LevelNone)
			action = NewListDisk(settingsService, platform, logger)
		})

		It("list disk should be synchronous", func() {
			Expect(action.IsAsynchronous()).To(BeFalse())
		})

		It("is not persistent", func() {
			Expect(action.IsPersistent()).To(BeFalse())
		})

		It("list disk run", func() {
			platform.MountedDevicePaths = []string{"/dev/sdb", "/dev/sdc"}

			settingsService.Settings.Disks = boshsettings.Disks{
				Persistent: map[string]string{
					"volume-1": "/dev/sda",
					"volume-2": "/dev/sdb",
					"volume-3": "/dev/sdc",
				},
			}

			value, err := action.Run()
			Expect(err).ToNot(HaveOccurred())
			boshassert.MatchesJSONString(GinkgoT(), value, `["volume-2","volume-3"]`)
		})
	})
}
