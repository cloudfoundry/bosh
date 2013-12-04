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
	fs, _, action := buildApplyAction()

	payload := []byte(`{"method":"apply","reply_to":"foo","arguments":[{"deployment":"dummy-damien"}]}`)
	_, err := action.Run(payload)
	assert.NoError(t, err)

	stats := fs.GetFileTestStat(boshsettings.VCAP_BASE_DIR + "/bosh/spec.json")
	assert.Equal(t, stats.FileType, fakesys.FakeFileTypeFile)
	assert.Equal(t, `{"deployment":"dummy-damien"}`, stats.Content)
}

func TestApplyRunSetsUpLogrotation(t *testing.T) {
	_, platform, action := buildApplyAction()

	payload := []byte(`{
		"method":"apply",
		"reply_to":"foo",
		"arguments":[{
			"properties":{
				"logging":{
					"max_log_file_size":"fake-size"
				}
			}
		}]
	}`)
	_, err := action.Run(payload)
	assert.NoError(t, err)

	assert.Equal(t, platform.SetupLogrotateArgs, fakeplatform.SetupLogrotateArgs{
		GroupName: boshsettings.VCAP_USERNAME,
		BasePath:  boshsettings.VCAP_BASE_DIR,
		Size:      "fake-size",
	})
}

func TestApplyRunErrsIfSetupLogrotateFails(t *testing.T) {
	_, platform, action := buildApplyAction()

	platform.SetupLogrotateErr = errors.New("fake-msg")

	payload := []byte(`{"method":"apply","reply_to":"foo","arguments":[{}]}`)
	_, err := action.Run(payload)

	assert.Error(t, err)
	assert.Contains(t, err.Error(), "Logrotate setup failed: fake-msg")
}

func TestApplyRunErrsWithZeroArguments(t *testing.T) {
	_, _, action := buildApplyAction()

	payload := []byte(`{"method":"apply","reply_to":"foo","arguments":[]}`)
	_, err := action.Run(payload)

	assert.Error(t, err)
	assert.Contains(t, err.Error(), "Not enough arguments")
}

func buildApplyAction() (*fakesys.FakeFileSystem, *fakeplatform.FakePlatform, applyAction) {
	platform := fakeplatform.NewFakePlatform()
	fs := platform.Fs
	action := newApply(fs, platform)
	return fs, platform, action
}
