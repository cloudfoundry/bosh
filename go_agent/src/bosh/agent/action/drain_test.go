package action

import (
	boshas "bosh/agent/applier/applyspec"
	fakeas "bosh/agent/applier/applyspec/fakes"
	fakedrain "bosh/agent/drain/fakes"
	fakenotif "bosh/notification/fakes"
	"errors"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestDrainShouldBeAsynchronous(t *testing.T) {
	_, _, action := buildDrain()
	assert.True(t, action.IsAsynchronous())
}

func TestDrainRunUpdateSkipsDrainScriptWhenWithoutDrainScript(t *testing.T) {
	_, fakeDrainProvider, action := buildDrain()

	newSpec := boshas.V1ApplySpec{
		PackageSpecs: map[string]boshas.PackageSpec{
			"foo": boshas.PackageSpec{
				Name: "foo",
				Sha1: "foo-sha1-new",
			},
		},
	}

	fakeDrainProvider.NewDrainScriptDrainScript.ExistsBool = false

	_, err := action.Run(drainTypeUpdate, newSpec)
	assert.NoError(t, err)
	assert.False(t, fakeDrainProvider.NewDrainScriptDrainScript.DidRun)
}

func TestDrainRunShutdownSkipsDrainScriptWhenWithoutDrainScript(t *testing.T) {
	_, fakeDrainProvider, action := buildDrain()

	newSpec := boshas.V1ApplySpec{
		PackageSpecs: map[string]boshas.PackageSpec{
			"foo": boshas.PackageSpec{
				Name: "foo",
				Sha1: "foo-sha1-new",
			},
		},
	}

	fakeDrainProvider.NewDrainScriptDrainScript.ExistsBool = false

	_, err := action.Run(drainTypeShutdown, newSpec)
	assert.NoError(t, err)
	assert.False(t, fakeDrainProvider.NewDrainScriptDrainScript.DidRun)
}

func TestDrainRunStatusErrsWhenWithoutDrainScript(t *testing.T) {
	_, fakeDrainProvider, action := buildDrain()

	fakeDrainProvider.NewDrainScriptDrainScript.ExistsBool = false

	_, err := action.Run(drainTypeStatus)
	assert.Error(t, err)
}

func TestDrainErrsWhenDrainScriptExitsWithError(t *testing.T) {
	_, fakeDrainScriptProvider, action := buildDrain()

	fakeDrainScriptProvider.NewDrainScriptDrainScript.RunExitStatus = 0
	fakeDrainScriptProvider.NewDrainScriptDrainScript.RunError = errors.New("Fake error")

	value, err := action.Run(drainTypeStatus)
	assert.Equal(t, value, 0)
	assert.Error(t, err)
}

func TestRunWithUpdateErrsIfNotGivenNewSpec(t *testing.T) {
	_, _, action := buildDrain()
	_, err := action.Run(drainTypeUpdate)
	assert.Error(t, err)
}

func TestRunWithUpdateRunsDrainWithUpdatedPackages(t *testing.T) {
	_, fakeDrainScriptProvider, action := buildDrain()

	newSpec := boshas.V1ApplySpec{
		PackageSpecs: map[string]boshas.PackageSpec{
			"foo": boshas.PackageSpec{
				Name: "foo",
				Sha1: "foo-sha1-new",
			},
		},
	}

	drainStatus, err := action.Run(drainTypeUpdate, newSpec)
	assert.NoError(t, err)
	assert.Equal(t, 1, drainStatus)
	assert.Equal(t, fakeDrainScriptProvider.NewDrainScriptTemplateName, "foo")
	assert.True(t, fakeDrainScriptProvider.NewDrainScriptDrainScript.DidRun)
	assert.Equal(t, fakeDrainScriptProvider.NewDrainScriptDrainScript.RunParams.JobChange(), "job_new")
	assert.Equal(t, fakeDrainScriptProvider.NewDrainScriptDrainScript.RunParams.HashChange(), "hash_new")
	assert.Equal(t, fakeDrainScriptProvider.NewDrainScriptDrainScript.RunParams.UpdatedPackages(), []string{"foo"})
}

func TestRunWithShutdown(t *testing.T) {
	fakeNotifier, fakeDrainScriptProvider, action := buildDrain()

	drainStatus, err := action.Run(drainTypeShutdown)
	assert.NoError(t, err)
	assert.Equal(t, 1, drainStatus)
	assert.Equal(t, fakeDrainScriptProvider.NewDrainScriptTemplateName, "foo")
	assert.True(t, fakeDrainScriptProvider.NewDrainScriptDrainScript.DidRun)
	assert.Equal(t, fakeDrainScriptProvider.NewDrainScriptDrainScript.RunParams.JobChange(), "job_shutdown")
	assert.Equal(t, fakeDrainScriptProvider.NewDrainScriptDrainScript.RunParams.HashChange(), "hash_unchanged")
	assert.Equal(t, fakeDrainScriptProvider.NewDrainScriptDrainScript.RunParams.UpdatedPackages(), []string{})
	assert.True(t, fakeNotifier.NotifiedShutdown)
}

func TestRunWithStatus(t *testing.T) {
	_, fakeDrainScriptProvider, action := buildDrain()

	drainStatus, err := action.Run(drainTypeStatus)
	assert.NoError(t, err)
	assert.Equal(t, 1, drainStatus)
	assert.Equal(t, fakeDrainScriptProvider.NewDrainScriptTemplateName, "foo")
	assert.True(t, fakeDrainScriptProvider.NewDrainScriptDrainScript.DidRun)
	assert.Equal(t, fakeDrainScriptProvider.NewDrainScriptDrainScript.RunParams.JobChange(), "job_check_status")
	assert.Equal(t, fakeDrainScriptProvider.NewDrainScriptDrainScript.RunParams.HashChange(), "hash_unchanged")
	assert.Equal(t, fakeDrainScriptProvider.NewDrainScriptDrainScript.RunParams.UpdatedPackages(), []string{})
}

func buildDrain() (
	notifier *fakenotif.FakeNotifier,
	fakeDrainProvider *fakedrain.FakeDrainScriptProvider,
	action drainAction,
) {
	notifier = fakenotif.NewFakeNotifier()

	specService := fakeas.NewFakeV1Service()
	currentSpec := boshas.V1ApplySpec{}
	currentSpec.JobSpec.Template = "foo"
	specService.Spec = currentSpec

	fakeDrainProvider = fakedrain.NewFakeDrainScriptProvider()
	fakeDrainProvider.NewDrainScriptDrainScript.ExistsBool = true

	action = newDrain(notifier, specService, fakeDrainProvider)

	return
}
