package action

import (
	boshas "bosh/agent/applier/applyspec"
	fakeas "bosh/agent/applier/applyspec/fakes"
	fakeappl "bosh/agent/applier/fakes"
	boshassert "bosh/assert"
	"errors"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestApplyShouldBeAsynchronous(t *testing.T) {
	_, _, action := buildApplyAction()
	assert.True(t, action.IsAsynchronous())
}

func TestApplyReturnsApplied(t *testing.T) {
	_, _, action := buildApplyAction()

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
	_, specService, action := buildApplyAction()

	applySpec := boshas.V1ApplySpec{
		JobSpec: boshas.JobSpec{
			Name: "router",
		},
	}

	_, err := action.Run(applySpec)
	assert.NoError(t, err)
	assert.Equal(t, applySpec, specService.Spec)
}

func TestApplyRunSkipsApplierWhenApplySpecDoesNotHaveConfigurationHash(t *testing.T) {
	applier, _, action := buildApplyAction()

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
	applier, _, action := buildApplyAction()

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
	applier, _, action := buildApplyAction()

	applier.ApplyError = errors.New("fake-apply-error")

	_, err := action.Run(boshas.V1ApplySpec{ConfigurationHash: "fake-config-hash"})
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "fake-apply-error")
}

func buildApplyAction() (*fakeappl.FakeApplier, *fakeas.FakeV1Service, applyAction) {
	applier := fakeappl.NewFakeApplier()
	specService := fakeas.NewFakeV1Service()
	action := newApply(applier, specService)
	return applier, specService, action
}
