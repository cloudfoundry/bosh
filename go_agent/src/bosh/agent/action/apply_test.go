package action

import (
	boshas "bosh/agent/applier/applyspec"
	fakeappl "bosh/agent/applier/fakes"
	boshassert "bosh/assert"
	fakeplatform "bosh/platform/fakes"
	boshsettings "bosh/settings"
	fakesys "bosh/system/fakes"
	"errors"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestApplyShouldBeAsynchronous(t *testing.T) {
	_, _, _, action := buildApplyAction()
	assert.True(t, action.IsAsynchronous())
}

func TestApplyReturnsApplied(t *testing.T) {
	_, _, _, action := buildApplyAction()

	applySpec := boshas.V1ApplySpec{
		JobSpec: boshas.JobSpec{
			Name: "router",
		},
	}

	value, err := action.Run(applySpec)
	assert.NoError(t, err)

	boshassert.MatchesJsonString(t, value, `"applied"`)
}

func TestApplyRunSavesTheFirstArgumentToSpecJson(t *testing.T) {
	_, fs, _, action := buildApplyAction()

	applySpec := boshas.V1ApplySpec{
		JobSpec: boshas.JobSpec{
			Name: "router",
		},
	}

	_, err := action.Run(applySpec)
	assert.NoError(t, err)

	stats := fs.GetFileTestStat(boshsettings.VCAP_BASE_DIR + "/bosh/spec.json")
	assert.Equal(t, stats.FileType, fakesys.FakeFileTypeFile)
	boshassert.MatchesJsonString(t, applySpec, stats.Content)
}

func TestApplyRunSkipsApplierWhenApplySpecDoesNotHaveConfigurationHash(t *testing.T) {
	applier, _, _, action := buildApplyAction()

	applySpec := boshas.V1ApplySpec{
		JobSpec: boshas.JobSpec{
			Template: "fake-job-template",
		},
	}

	_, err := action.Run(applySpec)
	assert.NoError(t, err)
	assert.False(t, applier.Applied)
}

func TestApplyRunRunsApplierWithApplySpecWhenApplySpecHasConfigurationHash(t *testing.T) {
	applier, _, _, action := buildApplyAction()

	expectedApplySpec := boshas.V1ApplySpec{
		JobSpec: boshas.JobSpec{
			Template: "fake-job-template",
		},
		ConfigurationHash: "fake-config-hash",
	}

	_, err := action.Run(expectedApplySpec)
	assert.NoError(t, err)
	assert.True(t, applier.Applied)
	assert.Equal(t, expectedApplySpec, applier.ApplyApplySpec)
}

func TestApplyRunErrsWhenApplierFails(t *testing.T) {
	applier, _, _, action := buildApplyAction()

	applier.ApplyError = errors.New("fake-apply-error")

	_, err := action.Run(boshas.V1ApplySpec{ConfigurationHash: "fake-config-hash"})
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "fake-apply-error")
}

func buildApplyAction() (*fakeappl.FakeApplier, *fakesys.FakeFileSystem, *fakeplatform.FakePlatform, applyAction) {
	applier := fakeappl.NewFakeApplier()
	platform := fakeplatform.NewFakePlatform()
	fs := platform.Fs
	action := newApply(applier, fs, platform)
	return applier, fs, platform, action
}
