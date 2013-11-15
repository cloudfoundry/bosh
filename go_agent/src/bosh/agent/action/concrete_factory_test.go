package action

import (
	testtask "bosh/agent/task/testhelpers"
	testplatform "bosh/platform/testhelpers"
	boshsettings "bosh/settings"
	testsys "bosh/system/testhelpers"
)

func getFakeFactoryDependencies() (settings boshsettings.Settings, fs *testsys.FakeFileSystem, platform *testplatform.FakePlatform, taskService *testtask.FakeService) {
	settings = boshsettings.Settings{}
	fs = &testsys.FakeFileSystem{}
	platform = testplatform.NewFakePlatform()
	taskService = &testtask.FakeService{}
	return
}
