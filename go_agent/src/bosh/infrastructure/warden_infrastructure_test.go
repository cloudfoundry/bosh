package infrastructure_test

import (
	"encoding/json"
	"errors"
	"github.com/stretchr/testify/assert"
	"os"
	"path/filepath"
	"time"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	. "bosh/infrastructure"
	fakedpresolv "bosh/infrastructure/devicepathresolver/fakes"
	fakeplatform "bosh/platform/fakes"
	boshsettings "bosh/settings"
	boshdir "bosh/settings/directories"
	fakesys "bosh/system/fakes"
)

var _ = Describe("wardenInfrastructure", func() {
	var (
		platform    *fakeplatform.FakePlatform
		dirProvider boshdir.DirectoriesProvider
		inf         Infrastructure
	)

	BeforeEach(func() {
		dirProvider = boshdir.NewDirectoriesProvider("/var/vcap")
		platform = fakeplatform.NewFakePlatform()
		fakeDevicePathResolver := fakedpresolv.NewFakeDevicePathResolver(1*time.Millisecond, platform.GetFs())
		inf = NewWardenInfrastructure(dirProvider, platform, fakeDevicePathResolver)
	})

	Describe("GetSettings", func() {
		Context("when infrastructure settings file is found", func() {
			BeforeEach(func() {
				settingsPath := filepath.Join(dirProvider.BoshDir(), "warden-cpi-agent-env.json")

				expectedSettings := boshsettings.Settings{
					AgentID: "123-456-789",
					Blobstore: boshsettings.Blobstore{
						Type: boshsettings.BlobstoreTypeDummy,
					},
					Mbus: "nats://127.0.0.1:4222",
				}
				existingSettingsBytes, err := json.Marshal(expectedSettings)
				Expect(err).ToNot(HaveOccurred())

				platform.Fs.WriteFile(settingsPath, existingSettingsBytes)
			})

			It("returns settings", func() {
				settings, err := inf.GetSettings()
				Expect(err).ToNot(HaveOccurred())
				assert.Equal(GinkgoT(), settings, boshsettings.Settings{
					AgentID:   "123-456-789",
					Blobstore: boshsettings.Blobstore{Type: boshsettings.BlobstoreTypeDummy},
					Mbus:      "nats://127.0.0.1:4222",
				})
			})
		})

		Context("when infrastructure settings file is not found", func() {
			It("returns error", func() {
				_, err := inf.GetSettings()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("Read settings file"))
			})
		})
	})

	Describe("MountPersistentDisk", func() {
		It("creates the mount directory with the correct permissions", func() {
			err := inf.MountPersistentDisk("fake-volume-id", "/mnt/point")
			Expect(err).ToNot(HaveOccurred())

			mountPoint := platform.Fs.GetFileTestStat("/mnt/point")
			Expect(mountPoint.FileType).To(Equal(fakesys.FakeFileTypeDir))
			Expect(mountPoint.FileMode).To(Equal(os.FileMode(0700)))
		})

		It("returns error when creating mount directory fails", func() {
			platform.Fs.MkdirAllError = errors.New("fake-mkdir-all-err")

			err := inf.MountPersistentDisk("fake-volume-id", "/mnt/point")
			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(ContainSubstring("fake-mkdir-all-err"))
		})

		It("mounts volume at mount point", func() {
			err := inf.MountPersistentDisk("fake-volume-id", "/mnt/point")
			Expect(err).ToNot(HaveOccurred())

			mounter := platform.FakeDiskManager.FakeMounter
			Expect(len(mounter.MountPartitionPaths)).To(Equal(1))
			Expect(mounter.MountPartitionPaths[0]).To(Equal("fake-volume-id"))
			Expect(mounter.MountMountPoints[0]).To(Equal("/mnt/point"))
			Expect(mounter.MountMountOptions[0]).To(Equal([]string{"--bind"}))
		})

		It("returns error when mounting fails", func() {
			platform.FakeDiskManager.FakeMounter.MountErr = errors.New("fake-mount-err")

			err := inf.MountPersistentDisk("fake-volume-id", "/mnt/point")
			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(ContainSubstring("fake-mount-err"))
		})
	})
})
