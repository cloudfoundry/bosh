package packageapplier_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	boshbc "bosh/agent/applier/bundlecollection"
	. "bosh/agent/applier/packageapplier"
	fakeblob "bosh/blobstore/fakes"
	boshlog "bosh/logger"
	fakecmd "bosh/platform/commands/fakes"
	fakesys "bosh/system/fakes"
)

var _ = Describe("concretePackageApplierProvider", func() {
	var (
		blobstore  *fakeblob.FakeBlobstore
		compressor *fakecmd.FakeCompressor
		fs         *fakesys.FakeFileSystem
		logger     boshlog.Logger
		provider   PackageApplierProvider
	)

	BeforeEach(func() {
		blobstore = fakeblob.NewFakeBlobstore()
		compressor = fakecmd.NewFakeCompressor()
		fs = fakesys.NewFakeFileSystem()
		logger = boshlog.NewLogger(boshlog.LevelNone)
		provider = NewConcretePackageApplierProvider(
			"fake-install-path",
			"fake-root-enable-path",
			"fake-job-specific-enable-path",
			"fake-name",
			blobstore,
			compressor,
			fs,
			logger,
		)
	})

	Describe("Root", func() {
		It("returns package applier that is configured to update system wide packages", func() {
			expected := NewConcretePackageApplier(
				boshbc.NewFileBundleCollection(
					"fake-install-path",
					"fake-root-enable-path",
					"fake-name",
					fs,
					logger,
				),
				true,
				blobstore,
				compressor,
				fs,
				logger,
			)
			Expect(provider.Root()).To(Equal(expected))
		})
	})

	Describe("JobSpecific", func() {
		It("returns package applier that is configured to only update job specific packages", func() {
			expected := NewConcretePackageApplier(
				boshbc.NewFileBundleCollection(
					"fake-install-path",
					"fake-job-specific-enable-path/fake-job-name",
					"fake-name",
					fs,
					logger,
				),

				// Should not operate as owner because keeping-only job specific packages
				// should not delete packages that could potentially be used by other jobs
				false,

				blobstore,
				compressor,
				fs,
				logger,
			)
			Expect(provider.JobSpecific("fake-job-name")).To(Equal(expected))
		})
	})
})
