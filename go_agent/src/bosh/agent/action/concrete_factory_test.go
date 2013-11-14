package action

import (
	testtask "bosh/agent/task/testhelpers"
	boshsettings "bosh/settings"
	testsys "bosh/system/testhelpers"
)

func getFakeFactoryDependencies() (settings boshsettings.Settings, fs *testsys.FakeFileSystem, taskService *testtask.FakeService) {
	settings = boshsettings.Settings{}
	fs = &testsys.FakeFileSystem{}
	taskService = &testtask.FakeService{}
	return
}
