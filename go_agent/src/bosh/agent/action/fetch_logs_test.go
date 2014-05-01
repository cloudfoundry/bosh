package action_test

import (
	"path/filepath"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	. "bosh/agent/action"
	boshassert "bosh/assert"
	fakeblobstore "bosh/blobstore/fakes"
	fakecmd "bosh/platform/commands/fakes"
	boshdirs "bosh/settings/directories"
)

var _ = Describe("FetchLogsAction", func() {
	var (
		compressor  *fakecmd.FakeCompressor
		copier      *fakecmd.FakeCopier
		blobstore   *fakeblobstore.FakeBlobstore
		dirProvider boshdirs.DirectoriesProvider
		action      FetchLogsAction
	)

	BeforeEach(func() {
		compressor = fakecmd.NewFakeCompressor()
		blobstore = &fakeblobstore.FakeBlobstore{}
		dirProvider = boshdirs.NewDirectoriesProvider("/fake/dir")
		copier = fakecmd.NewFakeCopier()
		action = NewFetchLogs(compressor, copier, blobstore, dirProvider)
	})

	It("logs should be asynchronous", func() {
		Expect(action.IsAsynchronous()).To(BeTrue())
	})

	It("is not persistent", func() {
		Expect(action.IsPersistent()).To(BeFalse())
	})

	Describe("Run", func() {
		testLogs := func(logType string, filters []string, expectedFilters []string) {
			copier.FilteredCopyToTempTempDir = "/fake-temp-dir"
			compressor.CompressFilesInDirTarballPath = "logs_test.tar"
			blobstore.CreateBlobID = "my-blob-id"

			logs, err := action.Run(logType, filters)
			Expect(err).ToNot(HaveOccurred())

			var expectedPath string
			switch logType {
			case "job":
				expectedPath = filepath.Join("/fake", "dir", "sys", "log")
			case "agent":
				expectedPath = filepath.Join("/fake", "dir", "bosh", "log")
			}

			Expect(copier.FilteredCopyToTempDir).To(Equal(expectedPath))
			Expect(copier.FilteredCopyToTempFilters).To(Equal(expectedFilters))

			Expect(copier.FilteredCopyToTempTempDir).To(Equal(compressor.CompressFilesInDirDir))
			Expect(copier.CleanUpTempDir).To(Equal(compressor.CompressFilesInDirDir))

			Expect(compressor.CompressFilesInDirTarballPath).To(Equal(blobstore.CreateFileName))

			boshassert.MatchesJSONString(GinkgoT(), logs, `{"blobstore_id":"my-blob-id"}`)
		}

		It("logs errs if given invalid log type", func() {
			_, err := action.Run("other-logs", []string{})
			Expect(err).To(HaveOccurred())
		})

		It("agent logs with filters", func() {
			filters := []string{"**/*.stdout.log", "**/*.stderr.log"}
			expectedFilters := []string{"**/*.stdout.log", "**/*.stderr.log"}
			testLogs("agent", filters, expectedFilters)
		})

		It("agent logs without filters", func() {
			filters := []string{}
			expectedFilters := []string{"**/*"}
			testLogs("agent", filters, expectedFilters)
		})

		It("job logs without filters", func() {
			filters := []string{}
			expectedFilters := []string{"**/*.log"}
			testLogs("job", filters, expectedFilters)
		})

		It("job logs with filters", func() {
			filters := []string{"**/*.stdout.log", "**/*.stderr.log"}
			expectedFilters := []string{"**/*.stdout.log", "**/*.stderr.log"}
			testLogs("job", filters, expectedFilters)
		})

		It("cleans up compressed package after uploading it to blobstore", func() {
			var beforeCleanUpTarballPath, afterCleanUpTarballPath string

			compressor.CompressFilesInDirTarballPath = "/fake-compressed-logs.tar"

			blobstore.CreateCallBack = func() {
				beforeCleanUpTarballPath = compressor.CleanUpTarballPath
			}

			_, err := action.Run("job", []string{})
			Expect(err).ToNot(HaveOccurred())

			// Logs are not cleaned up before blobstore upload
			Expect(beforeCleanUpTarballPath).To(Equal(""))

			// Deleted after it was uploaded
			afterCleanUpTarballPath = compressor.CleanUpTarballPath
			Expect(afterCleanUpTarballPath).To(Equal("/fake-compressed-logs.tar"))
		})
	})
})
