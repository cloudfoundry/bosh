package action

import (
	faketask "bosh/agent/task/fakes"
	fakeblobstore "bosh/blobstore/fakes"
	fakeplatform "bosh/platform/fakes"
	boshsettings "bosh/settings"
	fakesys "bosh/system/fakes"
)

func getFakeFactoryDependencies() (
	settings boshsettings.Settings,
	fs *fakesys.FakeFileSystem,
	platform *fakeplatform.FakePlatform,
	blobstore *fakeblobstore.FakeBlobstore,
	taskService *faketask.FakeService) {

	settings = boshsettings.Settings{}
	fs = &fakesys.FakeFileSystem{}
	platform = fakeplatform.NewFakePlatform()
	blobstore = &fakeblobstore.FakeBlobstore{}
	taskService = &faketask.FakeService{}
	return
}
