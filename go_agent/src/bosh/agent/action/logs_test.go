package action

import (
	boshassert "bosh/assert"
	fakeblobstore "bosh/blobstore/fakes"
	fakedisk "bosh/platform/disk/fakes"
	boshsettings "bosh/settings"
	"github.com/stretchr/testify/assert"
	"os"
	"path/filepath"
	"testing"
)

func TestLogsShouldBeAsynchronous(t *testing.T) {
	_, _, action := buildLogsAction()
	assert.True(t, action.IsAsynchronous())
}

func TestLogsWithFilters(t *testing.T) {
	filters := []string{"**/*.stdout.log", "**/*.stderr.log"}

	expectedFilters := []string{"**/*.stdout.log", "**/*.stderr.log"}
	testLogs(t, filters, expectedFilters)
}

func TestLogsWithoutFilters(t *testing.T) {
	filters := []string{}
	expectedFilters := []string{"**/*"}
	testLogs(t, filters, expectedFilters)
}

func testLogs(t *testing.T, filters []string, expectedFilters []string) {
	compressor, blobstore, action := buildLogsAction()

	var err error
	compressor.CompressFilesInDirTarball, err = os.Open("logs_test.go")
	blobstore.CreateBlobId = "my-blob-id"

	logs, err := action.Run("agent", filters)
	assert.NoError(t, err)

	expectedPath := filepath.Join(boshsettings.VCAP_BASE_DIR, "bosh", "log")
	assert.Equal(t, expectedPath, compressor.CompressFilesInDirDir)
	assert.Equal(t, expectedFilters, compressor.CompressFilesInDirFilters)

	// The log file is used when calling blobstore.Create
	assert.Equal(t, compressor.CompressFilesInDirTarball, blobstore.CreateFile)

	boshassert.MatchesJsonString(t, logs, `{"blobstore_id":"my-blob-id"}`)
}

func buildLogsAction() (*fakedisk.FakeCompressor, *fakeblobstore.FakeBlobstore, logsAction) {
	compressor := fakedisk.NewFakeCompressor()
	blobstore := &fakeblobstore.FakeBlobstore{}
	action := newLogs(compressor, blobstore)
	return compressor, blobstore, action
}
