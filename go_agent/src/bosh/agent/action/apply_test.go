package action

import (
	boshsettings "bosh/settings"
	fakesys "bosh/system/fakes"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestApplyRunSavesTheFirstArgumentToSpecJson(t *testing.T) {
	settings, fs, platform, blobstore, taskService := getFakeFactoryDependencies()
	factory := NewFactory(settings, fs, platform, blobstore, taskService)
	apply := factory.Create("apply")

	payload := []byte(`{"method":"apply","reply_to":"foo","arguments":[{"deployment":"dummy-damien"}]}`)
	_, err := apply.Run(payload)
	assert.NoError(t, err)

	stats := fs.GetFileTestStat(boshsettings.VCAP_BASE_DIR + "/bosh/spec.json")
	assert.Equal(t, stats.FileType, fakesys.FakeFileTypeFile)
	assert.Equal(t, `{"deployment":"dummy-damien"}`, stats.Content)
}

func TestApplyRunErrsWithZeroArguments(t *testing.T) {
	settings, fs, platform, blobstore, taskService := getFakeFactoryDependencies()
	factory := NewFactory(settings, fs, platform, blobstore, taskService)
	apply := factory.Create("apply")

	payload := []byte(`{"method":"apply","reply_to":"foo","arguments":[]}`)
	_, err := apply.Run(payload)

	assert.Error(t, err)
	assert.Contains(t, err.Error(), "Not enough arguments")
}
