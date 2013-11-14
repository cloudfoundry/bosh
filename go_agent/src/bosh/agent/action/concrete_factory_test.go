package action

import (
	testtask "bosh/agent/task/testhelpers"
	testsys "bosh/system/testhelpers"
)

func getFakeFactoryDependencies() (fs *testsys.FakeFileSystem, taskService *testtask.FakeService) {
	fs = &testsys.FakeFileSystem{}
	taskService = &testtask.FakeService{}
	return
}
