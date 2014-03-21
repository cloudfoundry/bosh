package action_test

import (
	"errors"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	. "bosh/agent/action"
	fakesettings "bosh/settings/fakes"
	fakesys "bosh/system/fakes"
)

func init() {
	Describe("prepareNetworkChange", func() {
		var (
			action          PrepareNetworkChangeAction
			fs              *fakesys.FakeFileSystem
			settingsService *fakesettings.FakeSettingsService
		)

		BeforeEach(func() {
			fs = fakesys.NewFakeFileSystem()
			settingsService = &fakesettings.FakeSettingsService{}
			action = NewPrepareNetworkChange(fs, settingsService)
		})

		It("is synchronous", func() {
			Expect(action.IsAsynchronous()).To(BeFalse())
		})

		It("is not persistent", func() {
			Expect(action.IsPersistent()).To(BeFalse())
		})

		It("invalidates settings so that load settings cannot fall back on old settings", func() {
			resp, err := action.Run()
			Expect(err).NotTo(HaveOccurred())
			Expect(resp).To(Equal("ok"))

			Expect(settingsService.SettingsWereInvalidated).To(BeTrue())
		})

		Context("when settings invalidation succeeds", func() {
			Context("when the network rules file can be removed", func() {
				It("removes the network rules file", func() {
					fs.WriteFile("/etc/udev/rules.d/70-persistent-net.rules", []byte{})

					resp, err := action.Run()
					Expect(err).NotTo(HaveOccurred())
					Expect(resp).To(Equal("ok"))

					Expect(fs.FileExists("/etc/udev/rules.d/70-persistent-net.rules")).To(BeFalse())
				})
			})

			Context("when the network rules file cannot be removed", func() {
				BeforeEach(func() {
					fs.RemoveAllError = errors.New("fake-remove-all-error")
				})

				It("returns error from removing the network rules file", func() {
					resp, err := action.Run()
					Expect(err).To(HaveOccurred())
					Expect(err.Error()).To(ContainSubstring("fake-remove-all-error"))

					Expect(resp).To(BeNil())
				})
			})
		})

		Context("when settings invalidation fails", func() {
			BeforeEach(func() {
				settingsService.InvalidateSettingsError = errors.New("fake-invalidate-error")
			})

			It("returns error early if settings err invalidating", func() {
				resp, err := action.Run()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("fake-invalidate-error"))

				Expect(resp).To(BeNil())
			})

			It("does not remove the network rules file", func() {
				fs.WriteFile("/etc/udev/rules.d/70-persistent-net.rules", []byte{})

				action.Run()
				Expect(fs.FileExists("/etc/udev/rules.d/70-persistent-net.rules")).To(BeTrue())
			})
		})
	})
}
