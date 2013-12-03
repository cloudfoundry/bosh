package action

import (
	boshassert "bosh/assert"
	boshsettings "bosh/settings"
	"github.com/stretchr/testify/assert"
	"os"
	"path/filepath"
	"testing"
)

func TestLogsWithFilters(t *testing.T) {
	payload := `{"arguments":["agent", ["**/*.stdout.log", "**/*.stderr.log"]]}`
	expectedFilters := []string{"**/*.stdout.log", "**/*.stderr.log"}
	testLogs(t, payload, expectedFilters)
}

func TestLogsWithoutFilters(t *testing.T) {
	payload := `{"arguments":["agent", []]}`
	expectedFilters := []string{"**/*"}
	testLogs(t, payload, expectedFilters)
}

func testLogs(t *testing.T, payload string, expectedFilters []string) {
	var err error

	settings, platform, blobstore, taskService := getFakeFactoryDependencies()
	compressor := platform.FakeCompressor

	compressor.CompressFilesInDirTarball, err = os.Open("logs_test.go")
	blobstore.CreateBlobId = "my-blob-id"
	assert.NoError(t, err)

	factory := NewFactory(settings, platform, blobstore, taskService)
	logsAction := factory.Create("fetch_logs")
	logs, err := logsAction.Run([]byte(payload))
	assert.NoError(t, err)

	expectedPath := filepath.Join(boshsettings.VCAP_BASE_DIR, "bosh", "log")
	assert.Equal(t, expectedPath, compressor.CompressFilesInDirDir)
	assert.Equal(t, expectedFilters, compressor.CompressFilesInDirFilters)

	// The log file is used when calling blobstore.Create
	assert.Equal(t, compressor.CompressFilesInDirTarball, blobstore.CreateFile)

	boshassert.MatchesJsonString(t, logs, `{"blobstore_id":"my-blob-id"}`)
}

func TestLogsWhenArgumentsAreMissing(t *testing.T) {
	settings, platform, blobstore, taskService := getFakeFactoryDependencies()
	factory := NewFactory(settings, platform, blobstore, taskService)
	logsAction := factory.Create("fetch_logs")

	_, err := logsAction.Run([]byte(`{"arguments":["agent"]}`))

	assert.Error(t, err)
	assert.Contains(t, err.Error(), "Not enough arguments in payload")
}
