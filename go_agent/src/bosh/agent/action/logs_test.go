package action

import (
	boshassert "bosh/assert"
	fakeblobstore "bosh/blobstore/fakes"
	fakecmd "bosh/platform/commands/fakes"
	boshdirs "bosh/settings/directories"
	"github.com/stretchr/testify/assert"
	"path/filepath"
	"testing"
)

func TestLogsShouldBeAsynchronous(t *testing.T) {
	_, action := buildLogsAction()
	assert.True(t, action.IsAsynchronous())
}

func TestLogsErrsIfGivenInvalidLogType(t *testing.T) {
	_, action := buildLogsAction()
	_, err := action.Run("other-logs", []string{})
	assert.Error(t, err)
}

func TestAgentLogsWithFilters(t *testing.T) {
	filters := []string{"**/*.stdout.log", "**/*.stderr.log"}

	expectedFilters := []string{"**/*.stdout.log", "**/*.stderr.log"}
	testLogs(t, "agent", filters, expectedFilters)
}

func TestAgentLogsWithoutFilters(t *testing.T) {
	filters := []string{}
	expectedFilters := []string{"**/*"}
	testLogs(t, "agent", filters, expectedFilters)
}

func TestJobLogsWithoutFilters(t *testing.T) {
	filters := []string{}
	expectedFilters := []string{"**/*.log"}
	testLogs(t, "job", filters, expectedFilters)
}

func TestJobLogsWithFilters(t *testing.T) {
	filters := []string{"**/*.stdout.log", "**/*.stderr.log"}

	expectedFilters := []string{"**/*.stdout.log", "**/*.stderr.log"}
	testLogs(t, "job", filters, expectedFilters)
}

func testLogs(t *testing.T, logType string, filters []string, expectedFilters []string) {
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

	// The log file is used when calling blobstore.Create
	assert.Equal(t, deps.compressor.CompressFilesInDirTarballPath, deps.blobstore.CreateFileName)

	boshassert.MatchesJsonString(t, logs, `{"blobstore_id":"my-blob-id"}`)
}

type logsDeps struct {
	compressor  *fakecmd.FakeCompressor
	copier      *fakecmd.FakeCopier
	blobstore   *fakeblobstore.FakeBlobstore
	dirProvider boshdirs.DirectoriesProvider
}

func buildLogsAction() (deps logsDeps, action logsAction) {
	deps = logsDeps{
		compressor:  fakecmd.NewFakeCompressor(),
		blobstore:   &fakeblobstore.FakeBlobstore{},
		dirProvider: boshdirs.NewDirectoriesProvider("/fake/dir"),
		copier:      fakecmd.NewFakeCopier(),
	}

	action = newLogs(
		deps.compressor,
		deps.copier,
		deps.blobstore,
		deps.dirProvider,
	)
	return
}
