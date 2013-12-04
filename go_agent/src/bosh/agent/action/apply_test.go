package action

import (
	boshas "bosh/agent/applyspec"
	fakeas "bosh/agent/applyspec/fakes"
	fakeplatform "bosh/platform/fakes"
	boshsettings "bosh/settings"
	fakesys "bosh/system/fakes"
	"errors"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestApplyRunSavesTheFirstArgumentToSpecJson(t *testing.T) {
	_, fs, _, action := buildApplyAction()

	payload := []byte(`{"method":"apply","reply_to":"foo","arguments":[{"deployment":"dummy-damien"}]}`)
	_, err := action.Run(payload)
	assert.NoError(t, err)

	stats := fs.GetFileTestStat(boshsettings.VCAP_BASE_DIR + "/bosh/spec.json")
	assert.Equal(t, stats.FileType, fakesys.FakeFileTypeFile)
	assert.Equal(t, `{"deployment":"dummy-damien"}`, stats.Content)
}

func TestApplyRunApplierToMakeChanges(t *testing.T) {
	applier, _, _, action := buildApplyAction()

	payload := []byte(`{
		"method":"apply",
		"reply_to":"foo",
		"arguments":[{
			"job":{
				"template":"fake-job-template"
			},
			"packages":[{
				"name":"fake-package-name"
			}]
		}]
	}`)

	_, err := action.Run(payload)
	assert.NoError(t, err)

	expectedJob := boshas.Job{Name: "fake-job-template"}
	assert.Equal(t, []boshas.Job{expectedJob}, applier.AppliedJobs)

	expectedPackage := boshas.Package{Name: "fake-package-name"}
	assert.Equal(t, []boshas.Package{expectedPackage}, applier.AppliedPackages)
}

func TestApplyRunErrsWhenApplierFails(t *testing.T) {
	applier, _, _, action := buildApplyAction()

	applier.ApplyError = errors.New("fake-apply-error")

	payload := []byte(`{"method":"apply","reply_to":"foo","arguments":[{}]}`)
	_, err := action.Run(payload)
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "fake-apply-error")
}

func TestApplyRunSetsUpLogrotation(t *testing.T) {
	_, _, platform, action := buildApplyAction()

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
	_, _, platform, action := buildApplyAction()

	platform.SetupLogrotateErr = errors.New("fake-msg")

	payload := []byte(`{"method":"apply","reply_to":"foo","arguments":[{}]}`)
	_, err := action.Run(payload)

	assert.Error(t, err)
	assert.Contains(t, err.Error(), "Logrotate setup failed: fake-msg")
}

func TestApplyRunErrsWithZeroArguments(t *testing.T) {
	_, _, _, action := buildApplyAction()

	payload := []byte(`{"method":"apply","reply_to":"foo","arguments":[]}`)
	_, err := action.Run(payload)

	assert.Error(t, err)
	assert.Contains(t, err.Error(), "Not enough arguments")
}

func buildApplyAction() (*fakeas.FakeApplier, *fakesys.FakeFileSystem, *fakeplatform.FakePlatform, applyAction) {
	applier := fakeas.NewFakeApplier()
	platform := fakeplatform.NewFakePlatform()
	fs := platform.Fs
	action := newApply(applier, fs, platform)
	return applier, fs, platform, action
}
