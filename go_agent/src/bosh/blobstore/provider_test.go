package blobstore_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	. "bosh/blobstore"
	boshlog "bosh/logger"
	fakeplatform "bosh/platform/fakes"
	boshsettings "bosh/settings"
	boshdir "bosh/settings/directories"
	boshuuid "bosh/uuid"
)

var _ = Describe("Provider", func() {
	var (
		platform *fakeplatform.FakePlatform
		logger   boshlog.Logger
		provider Provider
	)

	BeforeEach(func() {
		platform = fakeplatform.NewFakePlatform()
		dirProvider := boshdir.NewDirectoriesProvider("/var/vcap")
		logger = boshlog.NewLogger(boshlog.LevelNone)
		provider = NewProvider(platform, dirProvider, logger)
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
			options := map[string]interface{}{"key": "value"}

			platform.Runner.CommandExistsValue = true

			blobstore, err := provider.Get(boshsettings.Blobstore{
				Type:    "fake-external-type",
				Options: options,
			})
			Expect(err).ToNot(HaveOccurred())

			expectedBlobstore := NewExternalBlobstore(
				"fake-external-type",
				options,
				platform.GetFs(),
				platform.GetRunner(),
				boshuuid.NewGenerator(),
				"/var/vcap/bosh/etc/blobstore-fake-external-type.json",
			)
			expectedBlobstore = NewSHA1VerifiableBlobstore(expectedBlobstore)
			expectedBlobstore = NewRetryableBlobstore(expectedBlobstore, 3, logger)
			Expect(blobstore).To(Equal(expectedBlobstore))

			err = expectedBlobstore.Validate()
			Expect(err).ToNot(HaveOccurred())
		})

		It("get external errs when external command not in path", func() {
			options := map[string]interface{}{"key": "value"}

			platform.Runner.CommandExistsValue = false

			_, err := provider.Get(boshsettings.Blobstore{
				Type:    "fake-external-type",
				Options: options,
			})
			Expect(err).To(HaveOccurred())
		})
	})
})
