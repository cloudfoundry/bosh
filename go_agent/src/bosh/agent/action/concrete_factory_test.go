package action

import (
	fakeas "bosh/agent/applyspec/fakes"
	faketask "bosh/agent/task/fakes"
	fakeblobstore "bosh/blobstore/fakes"
	fakeplatform "bosh/platform/fakes"
	boshsettings "bosh/settings"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestNewFactory(t *testing.T) {
	actions := []string{
		"apply",
		"ping",
		"get_task",
		"get_state",
		"ssh",
		"fetch_logs",
		"start",
		"stop",
		"drain",
		"mount_disk",
	}

	_, _, factory := buildFactory()

	for _, actionName := range actions {
		action := factory.Create(actionName)
		assert.NotNil(t, action)
	}
}

func TestNewFactoryApply(t *testing.T) {
	platform, applier, factory := buildFactory()
	action := factory.Create("apply")
	assert.NotNil(t, action)
	assert.Equal(t, newApply(applier, platform.Fs, platform), action)
}

func buildFactory() (*fakeplatform.FakePlatform, *fakeas.FakeApplier, Factory) {
	settings := boshsettings.Settings{}
	platform := fakeplatform.NewFakePlatform()
	blobstore := &fakeblobstore.FakeBlobstore{}
	taskService := &faketask.FakeService{}
	applier := &fakeas.FakeApplier{}
	return platform, applier, NewFactory(settings, platform, blobstore, taskService, applier)
}
