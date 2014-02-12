package blobstore_test

import (
	. "bosh/blobstore"
	fakeplatform "bosh/platform/fakes"
	boshsettings "bosh/settings"
	boshdir "bosh/settings/directories"
	boshuuid "bosh/uuid"
	. "github.com/onsi/ginkgo"
	"github.com/stretchr/testify/assert"
)

func buildProvider() (platform *fakeplatform.FakePlatform, provider Provider) {
	platform = fakeplatform.NewFakePlatform()
	dirProvider := boshdir.NewDirectoriesProvider("/var/vcap")
	provider = NewProvider(platform, dirProvider)
	return
}
func init() {
	Describe("Testing with Ginkgo", func() {
		It("get dummy", func() {
			_, provider := buildProvider()
			blobstore, err := provider.Get(boshsettings.Blobstore{
				Type: boshsettings.BlobstoreTypeDummy,
			})
			assert.NoError(GinkgoT(), err)
			assert.NotNil(GinkgoT(), blobstore)
		})
		It("get external when external command in path", func() {

			platform, provider := buildProvider()
			options := map[string]string{
				"key": "value",
			}

			platform.Runner.CommandExistsValue = true
			blobstore, err := provider.Get(boshsettings.Blobstore{
				Type:    "fake-external-type",
				Options: options,
			})
			assert.NoError(GinkgoT(), err)

			expectedExternalConfigPath := "/var/vcap/bosh/etc/blobstore-fake-external-type.json"
			expectedBlobstore := NewExternalBlobstore("fake-external-type", options, platform.GetFs(), platform.GetRunner(), boshuuid.NewGenerator(), expectedExternalConfigPath)
			expectedBlobstore = NewSha1Verifiable(expectedBlobstore)
			err = expectedBlobstore.Validate()

			assert.NoError(GinkgoT(), err)
			assert.Equal(GinkgoT(), blobstore, expectedBlobstore)
		})
		It("get external errs when external command not in path", func() {

			platform, provider := buildProvider()
			options := map[string]string{
				"key": "value",
			}

			platform.Runner.CommandExistsValue = false
			_, err := provider.Get(boshsettings.Blobstore{
				Type:    "fake-external-type",
				Options: options,
			})
			assert.Error(GinkgoT(), err)
		})
	})
}
