package action_test

import (
	. "bosh/agent/action"
	boshassert "bosh/assert"
	fakeblobstore "bosh/blobstore/fakes"
	fakecmd "bosh/platform/commands/fakes"
	boshdirs "bosh/settings/directories"
	. "github.com/onsi/ginkgo"
	"github.com/stretchr/testify/assert"
	"path/filepath"
)

func testLogs(t assert.TestingT, logType string, filters []string, expectedFilters []string) {
	deps, action := buildLogsAction()

	deps.copier.FilteredCopyToTempTempDir = "/fake-temp-dir"
	deps.compressor.CompressFilesInDirTarballPath = "logs_test.go"
	deps.blobstore.CreateBlobId = "my-blob-id"

	logs, err := action.Run(logType, filters)
	assert.NoError(t, err)

	var expectedPath string
	switch logType {
	case "job":
		expectedPath = filepath.Join("/fake", "dir", "sys", "log")
	case "agent":
		expectedPath = filepath.Join("/fake", "dir", "bosh", "log")
	}

	assert.Equal(t, expectedPath, deps.copier.FilteredCopyToTempDir)
	assert.Equal(t, expectedFilters, deps.copier.FilteredCopyToTempFilters)

	assert.Equal(t, deps.copier.FilteredCopyToTempTempDir, deps.compressor.CompressFilesInDirDir)
	assert.Equal(t, deps.copier.CleanUpTempDir, deps.compressor.CompressFilesInDirDir)

	assert.Equal(t, deps.compressor.CompressFilesInDirTarballPath, deps.blobstore.CreateFileName)

	boshassert.MatchesJsonString(t, logs, `{"blobstore_id":"my-blob-id"}`)
}

type logsDeps struct {
	compressor  *fakecmd.FakeCompressor
	copier      *fakecmd.FakeCopier
	blobstore   *fakeblobstore.FakeBlobstore
	dirProvider boshdirs.DirectoriesProvider
}

func buildLogsAction() (deps logsDeps, action LogsAction) {
	deps = logsDeps{
		compressor:  fakecmd.NewFakeCompressor(),
		blobstore:   &fakeblobstore.FakeBlobstore{},
		dirProvider: boshdirs.NewDirectoriesProvider("/fake/dir"),
		copier:      fakecmd.NewFakeCopier(),
	}

	action = NewLogs(
		deps.compressor,
		deps.copier,
		deps.blobstore,
		deps.dirProvider,
	)
	return
}
func init() {
	Describe("Testing with Ginkgo", func() {
		It("logs should be asynchronous", func() {
			_, action := buildLogsAction()
			assert.True(GinkgoT(), action.IsAsynchronous())
		})
		It("logs errs if given invalid log type", func() {

			_, action := buildLogsAction()
			_, err := action.Run("other-logs", []string{})
			assert.Error(GinkgoT(), err)
		})
		It("agent logs with filters", func() {

			filters := []string{"**/*.stdout.log", "**/*.stderr.log"}

			expectedFilters := []string{"**/*.stdout.log", "**/*.stderr.log"}
			testLogs(GinkgoT(), "agent", filters, expectedFilters)
		})
		It("agent logs without filters", func() {

			filters := []string{}
			expectedFilters := []string{"**/*"}
			testLogs(GinkgoT(), "agent", filters, expectedFilters)
		})
		It("job logs without filters", func() {

			filters := []string{}
			expectedFilters := []string{"**/*.log"}
			testLogs(GinkgoT(), "job", filters, expectedFilters)
		})
		It("job logs with filters", func() {

			filters := []string{"**/*.stdout.log", "**/*.stderr.log"}

			expectedFilters := []string{"**/*.stdout.log", "**/*.stderr.log"}
			testLogs(GinkgoT(), "job", filters, expectedFilters)
		})
	})
}
