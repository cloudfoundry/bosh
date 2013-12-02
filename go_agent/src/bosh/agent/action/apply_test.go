package action

import (
	fakeplatform "bosh/platform/fakes"
	boshsettings "bosh/settings"
	fakesys "bosh/system/fakes"
	"errors"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestApplyRunSavesTheFirstArgumentToSpecJson(t *testing.T) {
	settings, platform, blobstore, taskService := getFakeFactoryDependencies()
	factory := NewFactory(settings, platform, blobstore, taskService)
	apply := factory.Create("apply")

	payload := []byte(`{"method":"apply","reply_to":"foo","arguments":[{"deployment":"dummy-damien"}]}`)
	_, err := apply.Run(payload)
	assert.NoError(t, err)

	stats := platform.Fs.GetFileTestStat(boshsettings.VCAP_BASE_DIR + "/bosh/spec.json")
	assert.Equal(t, stats.FileType, fakesys.FakeFileTypeFile)
	assert.Equal(t, `{"deployment":"dummy-damien"}`, stats.Content)
}

func TestApplyRunSetsUpLogrotation(t *testing.T) {
	settings, platform, blobstore, taskService := getFakeFactoryDependencies()
	factory := NewFactory(settings, platform, blobstore, taskService)
	apply := factory.Create("apply")

	payload := []byte(`{"method":"apply","reply_to":"foo","arguments":[{}]}`)
	_, err := apply.Run(payload)
	assert.NoError(t, err)

	assert.Equal(t, platform.SetupLogrotateArgs, fakeplatform.SetupLogrotateArgs{
		GroupName: boshsettings.VCAP_USERNAME,
		BasePath:  boshsettings.VCAP_BASE_DIR,
		Size:      "50M",
	})
}

func TestApplyRunErrsIfSetupLogrotateFails(t *testing.T) {
	settings, platform, blobstore, taskService := getFakeFactoryDependencies()
	factory := NewFactory(settings, platform, blobstore, taskService)
	apply := factory.Create("apply")

	platform.SetupLogrotateErr = errors.New("fake-msg")

	payload := []byte(`{"method":"apply","reply_to":"foo","arguments":[{}]}`)
	_, err := apply.Run(payload)

	assert.Error(t, err)
	assert.Contains(t, err.Error(), "Logrotate setup failed: fake-msg")
}

func TestApplyRunErrsWithZeroArguments(t *testing.T) {
	settings, platform, blobstore, taskService := getFakeFactoryDependencies()
	factory := NewFactory(settings, platform, blobstore, taskService)
	apply := factory.Create("apply")

	payload := []byte(`{"method":"apply","reply_to":"foo","arguments":[]}`)
	_, err := apply.Run(payload)

	assert.Error(t, err)
	assert.Contains(t, err.Error(), "Not enough arguments")
}
