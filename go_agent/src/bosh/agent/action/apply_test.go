package action

import (
	boshas "bosh/agent/applier/applyspec"
	fakeappl "bosh/agent/applier/fakes"
	fakeplatform "bosh/platform/fakes"
	boshsettings "bosh/settings"
	fakesys "bosh/system/fakes"
	"errors"
	"fmt"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestApplyShouldBeAsynchronous(t *testing.T) {
	_, _, _, action := buildApplyAction()
	assert.True(t, action.IsAsynchronous())
}

func TestApplyRunSavesTheFirstArgumentToSpecJson(t *testing.T) {
	_, fs, _, action := buildApplyAction()

	payload := []byte(`{"method":"apply","reply_to":"foo","arguments":[{"deployment":"dummy-damien"}]}`)
	_, err := action.Run(payload)
	assert.NoError(t, err)

	stats := fs.GetFileTestStat(boshsettings.VCAP_BASE_DIR + "/bosh/spec.json")
	assert.Equal(t, stats.FileType, fakesys.FakeFileTypeFile)
	assert.Equal(t, `{"deployment":"dummy-damien"}`, stats.Content)
}

func TestApplyRunRunsApplierWithApplySpec(t *testing.T) {
	applier, _, _, action := buildApplyAction()

	applySpecPayload := []byte(`{"job": {"template": "fake-job-template"}}`)

	expectedApplySpec, err := boshas.NewV1ApplySpecFromJson(applySpecPayload)
	assert.NoError(t, err)

	payload := []byte(
		fmt.Sprintf(`{
			"method":    "apply",
			"reply_to":  "foo",
			"arguments": [%s]
		}`, applySpecPayload),
	)

	_, err = action.Run(payload)
	assert.NoError(t, err)
	assert.Equal(t, expectedApplySpec, applier.ApplyApplySpec)
}

func TestApplyRunErrsWhenApplierFails(t *testing.T) {
	applier, _, _, action := buildApplyAction()

	applier.ApplyError = errors.New("fake-apply-error")

	payload := []byte(`{"method":"apply","reply_to":"foo","arguments":[{}]}`)
	_, err := action.Run(payload)
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "fake-apply-error")
}

func TestApplyRunErrsWithZeroArguments(t *testing.T) {
	_, _, _, action := buildApplyAction()

	payload := []byte(`{"method":"apply","reply_to":"foo","arguments":[]}`)
	_, err := action.Run(payload)

	assert.Error(t, err)
	assert.Contains(t, err.Error(), "Not enough arguments")
}

func buildApplyAction() (*fakeappl.FakeApplier, *fakesys.FakeFileSystem, *fakeplatform.FakePlatform, applyAction) {
	applier := fakeappl.NewFakeApplier()
	platform := fakeplatform.NewFakePlatform()
	fs := platform.Fs
	action := newApply(applier, fs, platform)
	return applier, fs, platform, action
}
