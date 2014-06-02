package action_test

import (
	"errors"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	. "bosh/agent/action"
	fakeplatform "bosh/platform/fakes"
	fakesettings "bosh/settings/fakes"
)

var _ = Describe("prepareConfigureNetworks", func() {
	var (
		action          PrepareConfigureNetworksAction
		platform        *fakeplatform.FakePlatform
		settingsService *fakesettings.FakeSettingsService
	)

	BeforeEach(func() {
		platform = fakeplatform.NewFakePlatform()
		settingsService = &fakesettings.FakeSettingsService{}
		action = NewPrepareConfigureNetworks(platform, settingsService)
	})

	It("is synchronous", func() {
		Expect(action.IsAsynchronous()).To(BeFalse())
	})

	It("is not persistent", func() {
		Expect(action.IsPersistent()).To(BeFalse())
	})

	Describe("Run", func() {
		It("invalidates settings so that load settings cannot fall back on old settings", func() {
			resp, err := action.Run()
			Expect(err).NotTo(HaveOccurred())
			Expect(resp).To(Equal("ok"))

			Expect(settingsService.SettingsWereInvalidated).To(BeTrue())
		})

		Context("when settings invalidation succeeds", func() {
			It("prepares platform for networking change", func() {
				resp, err := action.Run()
				Expect(err).NotTo(HaveOccurred())
				Expect(resp).To(Equal("ok"))

				Expect(platform.PrepareForNetworkingChangeCalled).To(BeTrue())
			})

			It("returns error if preparing for networking change fails", func() {
				platform.PrepareForNetworkingChangeErr = errors.New("fake-prepare-error")

				resp, err := action.Run()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("fake-prepare-error"))

				Expect(resp).To(Equal(""))
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

				Expect(resp).To(Equal(""))
			})

			It("does not prepare platform for networking change", func() {
				_, err := action.Run()
				Expect(err).To(HaveOccurred())

				Expect(platform.PrepareForNetworkingChangeCalled).To(BeFalse())
			})
		})
	})
})
