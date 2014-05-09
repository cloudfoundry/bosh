package blobstore_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	. "bosh/blobstore"
	fakeplatform "bosh/platform/fakes"
	boshsettings "bosh/settings"
	boshdir "bosh/settings/directories"
	boshuuid "bosh/uuid"
)

var _ = Describe("Provider", func() {
	var (
		platform *fakeplatform.FakePlatform
		provider Provider
	)

	BeforeEach(func() {
		platform = fakeplatform.NewFakePlatform()
		dirProvider := boshdir.NewDirectoriesProvider("/var/vcap")
		provider = NewProvider(platform, dirProvider)
	})

	Describe("Get", func() {
		It("get dummy", func() {
			blobstore, err := provider.Get(boshsettings.Blobstore{
				Type: boshsettings.BlobstoreTypeDummy,
			})
			Expect(err).ToNot(HaveOccurred())
			Expect(blobstore).ToNot(BeNil())
		})

		It("get external when external command in path", func() {
			options := map[string]interface{}{
				"key": "value",
			}

			platform.Runner.CommandExistsValue = true
			blobstore, err := provider.Get(boshsettings.Blobstore{
				Type:    "fake-external-type",
				Options: options,
			})
			Expect(err).ToNot(HaveOccurred())

			expectedExternalConfigPath := "/var/vcap/bosh/etc/blobstore-fake-external-type.json"
			expectedBlobstore := NewExternalBlobstore("fake-external-type", options, platform.GetFs(), platform.GetRunner(), boshuuid.NewGenerator(), expectedExternalConfigPath)
			expectedBlobstore = NewSha1Verifiable(expectedBlobstore)
			err = expectedBlobstore.Validate()

			Expect(err).ToNot(HaveOccurred())
			Expect(blobstore).To(Equal(expectedBlobstore))
		})

		It("get external errs when external command not in path", func() {
			options := map[string]interface{}{
				"key": "value",
			}

			platform.Runner.CommandExistsValue = false
			_, err := provider.Get(boshsettings.Blobstore{
				Type:    "fake-external-type",
				Options: options,
			})
			Expect(err).To(HaveOccurred())
		})
	})
})
