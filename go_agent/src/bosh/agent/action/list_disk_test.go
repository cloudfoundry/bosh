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
	Describe("Testing with Ginkgo", func() {
		var (
			logger   boshlog.Logger
			platform *fakeplatform.FakePlatform
		)

		BeforeEach(func() {
			platform = fakeplatform.NewFakePlatform()
			logger = boshlog.NewLogger(boshlog.LevelNone)
		})

		It("list disk should be synchronous", func() {
			settings := &fakesettings.FakeSettingsService{}
			action := NewListDisk(settings, platform, logger)
			Expect(action.IsAsynchronous()).To(BeFalse())
		})

		It("is not persistent", func() {
			settings := &fakesettings.FakeSettingsService{}
			action := NewListDisk(settings, platform, logger)
			Expect(action.IsPersistent()).To(BeFalse())
		})

		It("list disk run", func() {
			settings := &fakesettings.FakeSettingsService{
				Disks: boshsettings.Disks{
					Persistent: map[string]string{
						"volume-1": "/dev/sda",
						"volume-2": "/dev/sdb",
						"volume-3": "/dev/sdc",
					},
				},
			}
			platform.MountedDevicePaths = []string{"/dev/sdb", "/dev/sdc"}

			action := NewListDisk(settings, platform, logger)
			value, err := action.Run()
			Expect(err).ToNot(HaveOccurred())
			boshassert.MatchesJSONString(GinkgoT(), value, `["volume-2","volume-3"]`)
		})
	})
}
