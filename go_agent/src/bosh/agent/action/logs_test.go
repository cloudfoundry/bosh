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
	_, _, action := buildLogsAction()
	assert.True(t, action.IsAsynchronous())
}

func TestLogsErrsIfGivenInvalidLogType(t *testing.T) {
	_, _, action := buildLogsAction()
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
	compressor, blobstore, action := buildLogsAction()

	compressor.CompressFilesInDirTarballPath = "logs_test.go"
	blobstore.CreateBlobId = "my-blob-id"

	logs, err := action.Run(logType, filters)
	assert.NoError(t, err)

	var expectedPath string
	switch logType {
	case "job":
		expectedPath = filepath.Join("/fake", "dir", "sys", "log")
	case "agent":
		expectedPath = filepath.Join("/fake", "dir", "bosh", "log")
	}
	assert.Equal(t, expectedPath, compressor.CompressFilesInDirDir)
	assert.Equal(t, expectedFilters, compressor.CompressFilesInDirFilters)

	// The log file is used when calling blobstore.Create
	assert.Equal(t, compressor.CompressFilesInDirTarballPath, blobstore.CreateFileName)

	boshassert.MatchesJsonString(t, logs, `{"blobstore_id":"my-blob-id"}`)
}

func buildLogsAction() (*fakecmd.FakeCompressor, *fakeblobstore.FakeBlobstore, logsAction) {
	compressor := fakecmd.NewFakeCompressor()
	blobstore := &fakeblobstore.FakeBlobstore{}
	dirProvider := boshdirs.NewDirectoriesProvider("/fake/dir")
	action := newLogs(compressor, blobstore, dirProvider)
	return compressor, blobstore, action
}
