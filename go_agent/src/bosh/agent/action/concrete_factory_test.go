package action

import (
	faketask "bosh/agent/task/fakes"
	fakeblobstore "bosh/blobstore/fakes"
	fakeplatform "bosh/platform/fakes"
	boshsettings "bosh/settings"
	"github.com/stretchr/testify/assert"
	"testing"
)

func getFakeFactoryDependencies() (
	settings boshsettings.Settings,
	platform *fakeplatform.FakePlatform,
	blobstore *fakeblobstore.FakeBlobstore,
	taskService *faketask.FakeService,
) {
	settings = boshsettings.Settings{}
	platform = fakeplatform.NewFakePlatform()
	blobstore = &fakeblobstore.FakeBlobstore{}
	taskService = &faketask.FakeService{}
	return
}

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

	factory := buildFactory()

	for _, actionName := range actions {
		action := factory.Create(actionName)
		assert.NotNil(t, action)
	}
}

func buildFactory() Factory {
	settings, platform, blobstore, taskService := getFakeFactoryDependencies()
	return NewFactory(settings, platform, blobstore, taskService)
}
