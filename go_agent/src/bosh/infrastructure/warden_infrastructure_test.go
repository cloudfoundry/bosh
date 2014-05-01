package infrastructure_test

import (
	"encoding/json"
	"path/filepath"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
	"github.com/stretchr/testify/assert"

	. "bosh/infrastructure"
	fakedpresolv "bosh/infrastructure/devicepathresolver/fakes"
	fakeplatform "bosh/platform/fakes"
	boshsettings "bosh/settings"
	boshdir "bosh/settings/directories"
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
		fakeDevicePathResolver := fakedpresolv.NewFakeDevicePathResolver()
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
})
