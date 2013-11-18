package action

import (
	faketask "bosh/agent/task/fakes"
	fakeplatform "bosh/platform/fakes"
	boshsettings "bosh/settings"
	fakesys "bosh/system/fakes"
)

func getFakeFactoryDependencies() (settings boshsettings.Settings, fs *fakesys.FakeFileSystem, platform *fakeplatform.FakePlatform, taskService *faketask.FakeService) {
	settings = boshsettings.Settings{}
	fs = &fakesys.FakeFileSystem{}
	platform = fakeplatform.NewFakePlatform()
	taskService = &faketask.FakeService{}
	return
}
