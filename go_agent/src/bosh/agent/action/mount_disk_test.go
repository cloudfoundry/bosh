package action_test

import (
	"errors"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	. "bosh/agent/action"
	fakeplatform "bosh/platform/fakes"
	boshdirs "bosh/settings/directories"
	fakesettings "bosh/settings/fakes"
)

var _ = Describe("MountDiskAction", func() {
	var (
		settingsService *fakesettings.FakeSettingsService
		platform        *fakeplatform.FakePlatform
		action          MountDiskAction
	)

	BeforeEach(func() {
		settingsService = &fakesettings.FakeSettingsService{}
		platform = fakeplatform.NewFakePlatform()
		dirProvider := boshdirs.NewDirectoriesProvider("/fake-base-dir")
		action = NewMountDisk(settingsService, platform, platform, dirProvider)
	})

	It("is asynchronous", func() {
		Expect(action.IsAsynchronous()).To(BeTrue())
	})

	It("is not persistent", func() {
		Expect(action.IsPersistent()).To(BeFalse())
	})

	Describe("Run", func() {
		Context("when settings can be loaded", func() {
			Context("when disk cid can be resolved to a device path from infrastructure settings", func() {
				BeforeEach(func() {
					settingsService.Settings.Disks.Persistent = map[string]string{
						"fake-disk-cid": "fake-device-path",
					}
				})

				It("checks if store directory is already mounted", func() {
					_, err := action.Run("fake-disk-cid")
					Expect(err).NotTo(HaveOccurred())
					Expect(platform.IsMountPointPath).To(Equal("/fake-base-dir/store"))
				})

				Context("when store directory is not mounted", func() {
					BeforeEach(func() {
						platform.IsMountPointResult = false
					})

					Context("when mounting succeeds", func() {
						It("returns without an error after mounting store directory", func() {
							result, err := action.Run("fake-disk-cid")
							Expect(err).NotTo(HaveOccurred())
							Expect(result).To(Equal(map[string]string{}))

							Expect(platform.MountPersistentDiskDevicePath).To(Equal("fake-device-path"))
							Expect(platform.MountPersistentDiskMountPoint).To(Equal("/fake-base-dir/store"))
						})
					})

					Context("when mounting fails", func() {
						It("returns error after trying to mount store directory", func() {
							platform.MountPersistentDiskErr = errors.New("fake-mount-persistent-disk-err")

							_, err := action.Run("fake-disk-cid")
							Expect(err).To(HaveOccurred())
							Expect(err.Error()).To(ContainSubstring("fake-mount-persistent-disk-err"))
						})
					})
				})

				Context("when store directory is already mounted", func() {
					BeforeEach(func() {
						platform.IsMountPointResult = true
					})

					Context("when mounting succeeds", func() {
						It("returns without an error after mounting store migration directory", func() {
							result, err := action.Run("fake-disk-cid")
							Expect(err).NotTo(HaveOccurred())
							Expect(result).To(Equal(map[string]string{}))

							Expect(platform.MountPersistentDiskDevicePath).To(Equal("fake-device-path"))
							Expect(platform.MountPersistentDiskMountPoint).To(Equal("/fake-base-dir/store_migration_target"))
						})
					})

					Context("when mounting fails", func() {
						It("returns error after trying to mount store migration directory", func() {
							platform.MountPersistentDiskErr = errors.New("fake-mount-persistent-disk-err")

							_, err := action.Run("fake-disk-cid")
							Expect(err).To(HaveOccurred())
							Expect(err.Error()).To(ContainSubstring("fake-mount-persistent-disk-err"))
						})
					})
				})

				Context("when store directory cannot be determined if it is mounted", func() {
					BeforeEach(func() {
						platform.IsMountPointErr = errors.New("fake-is-mount-point-err")
					})

					It("returns error", func() {
						_, err := action.Run("fake-disk-cid")
						Expect(err).To(HaveOccurred())
						Expect(err.Error()).To(ContainSubstring("fake-is-mount-point-err"))
					})

					It("does not try to mount disk", func() {
						_, err := action.Run("fake-disk-cid")
						Expect(err).To(HaveOccurred())
						Expect(platform.MountPersistentDiskCalled).To(BeFalse())
					})
				})
			})

			Context("when disk cid cannot be resolved to a device path from infrastructure settings", func() {
				BeforeEach(func() {
					settingsService.Settings.Disks.Persistent = map[string]string{
						"fake-known-disk-cid": "/dev/sdf",
					}
				})

				It("returns error", func() {
					_, err := action.Run("fake-unknown-disk-cid")
					Expect(err).To(HaveOccurred())
					Expect(err.Error()).To(Equal("Persistent disk with volume id 'fake-unknown-disk-cid' could not be found"))
				})
			})
		})

		Context("when settings cannot be loaded", func() {
			It("returns error", func() {
				settingsService.LoadSettingsError = errors.New("fake-load-settings-err")

				_, err := action.Run("fake-disk-cid")
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("fake-load-settings-err"))
			})
		})
	})
})
