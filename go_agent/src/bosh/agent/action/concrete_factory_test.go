package action

import (
	fakeas "bosh/agent/applier/applyspec/fakes"
	fakeappl "bosh/agent/applier/fakes"
	fakecomp "bosh/agent/compiler/fakes"
	faketask "bosh/agent/task/fakes"
	fakeblobstore "bosh/blobstore/fakes"
	fakemon "bosh/monitor/fakes"
	fakenotif "bosh/notification/fakes"
	fakeplatform "bosh/platform/fakes"
	fakesettings "bosh/settings/fakes"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestNewFactory(t *testing.T) {
	actions := []string{
		"apply",
		"drain",
		"fetch_logs",
		"get_task",
		"get_state",
		"list_disk",
		"migrate_disk",
		"mount_disk",
		"ping",
		"prepare_network_change",
		"ssh",
		"start",
		"stop",
		"unmount_disk",
		"compile_package",
	}

	_, _, _, _, _, _, _, _, _, factory := buildFactory()

	for _, actionName := range actions {
		action, err := factory.Create(actionName)
		assert.NoError(t, err)
		assert.NotNil(t, action)
	}

	action, err := factory.Create("gobberish")
	assert.Error(t, err)
	assert.Nil(t, action)
}

func TestNewFactoryApply(t *testing.T) {
	_, _, _, _, _, applier, _, _, specService, factory := buildFactory()
	action, err := factory.Create("apply")
	assert.NoError(t, err)
	assert.NotNil(t, action)
	assert.Equal(t, newApply(applier, specService), action)
}

func TestNewFactoryDrain(t *testing.T) {
	_, platform, _, _, notifier, _, _, _, specService, factory := buildFactory()
	action, err := factory.Create("drain")
	assert.NoError(t, err)
	assert.NotNil(t, action)
	assert.Equal(t, newDrain(platform.Runner, platform.Fs, notifier, specService), action)
}

func TestNewFactoryFetchLogs(t *testing.T) {
	_, platform, blobstore, _, _, _, _, _, _, factory := buildFactory()
	action, err := factory.Create("fetch_logs")
	assert.NoError(t, err)
	assert.NotNil(t, action)
	assert.Equal(t, newLogs(platform.GetCompressor(), blobstore), action)
}

func TestNewFactoryGetTask(t *testing.T) {
	_, _, _, taskService, _, _, _, _, _, factory := buildFactory()
	action, err := factory.Create("get_task")
	assert.NoError(t, err)
	assert.NotNil(t, action)
	assert.Equal(t, newGetTask(taskService), action)
}

func TestNewFactoryGetState(t *testing.T) {
	settings, _, _, _, _, _, _, monitor, specService, factory := buildFactory()
	action, err := factory.Create("get_state")
	assert.NoError(t, err)
	assert.NotNil(t, action)
	assert.Equal(t, newGetState(settings, specService, monitor), action)
}

func TestNewFactoryListDisk(t *testing.T) {
	settings, platform, _, _, _, _, _, _, _, factory := buildFactory()
	action, err := factory.Create("list_disk")
	assert.NoError(t, err)
	assert.NotNil(t, action)
	assert.Equal(t, newListDisk(settings, platform), action)
}

func TestNewFactoryMigrateDisk(t *testing.T) {
	settings, platform, _, _, _, _, _, _, _, factory := buildFactory()
	action, err := factory.Create("migrate_disk")
	assert.NoError(t, err)
	assert.NotNil(t, action)
	assert.Equal(t, newMigrateDisk(settings, platform), action)
}

func TestNewFactoryMountDisk(t *testing.T) {
	settings, platform, _, _, _, _, _, _, _, factory := buildFactory()
	action, err := factory.Create("mount_disk")
	assert.NoError(t, err)
	assert.NotNil(t, action)
	assert.Equal(t, newMountDisk(settings, platform), action)
}

func TestNewFactorySsh(t *testing.T) {
	settings, platform, _, _, _, _, _, _, _, factory := buildFactory()
	action, err := factory.Create("ssh")
	assert.NoError(t, err)
	assert.NotNil(t, action)
	assert.Equal(t, newSsh(settings, platform), action)
}

func TestNewFactoryStart(t *testing.T) {
	_, _, _, _, _, _, _, monitor, _, factory := buildFactory()
	action, err := factory.Create("start")
	assert.NoError(t, err)
	assert.NotNil(t, action)
	assert.Equal(t, newStart(monitor), action)
}

func TestNewFactoryUnmountDisk(t *testing.T) {
	settings, platform, _, _, _, _, _, _, _, factory := buildFactory()
	action, err := factory.Create("unmount_disk")
	assert.NoError(t, err)
	assert.NotNil(t, action)
	assert.Equal(t, newUnmountDisk(settings, platform), action)
}

func TestNewFactoryCompilePackage(t *testing.T) {
	_, _, _, _, _, _, compiler, _, _, factory := buildFactory()
	action, err := factory.Create("compile_package")
	assert.NoError(t, err)
	assert.NotNil(t, action)
	assert.Equal(t, newCompilePackage(compiler),
		action)
}

func buildFactory() (
	settings *fakesettings.FakeSettingsService,
	platform *fakeplatform.FakePlatform,
	blobstore *fakeblobstore.FakeBlobstore,
	taskService *faketask.FakeService,
	notifier *fakenotif.FakeNotifier,
	applier *fakeappl.FakeApplier,
	compiler *fakecomp.FakeCompiler,
	monitor *fakemon.FakeMonitor,
	specService *fakeas.FakeV1Service,
	factory Factory) {

	settings = &fakesettings.FakeSettingsService{}
	platform = fakeplatform.NewFakePlatform()
	blobstore = &fakeblobstore.FakeBlobstore{}
	taskService = &faketask.FakeService{}
	notifier = fakenotif.NewFakeNotifier()
	applier = fakeappl.NewFakeApplier()
	compiler = fakecomp.NewFakeCompiler()
	monitor = fakemon.NewFakeMonitor()
	specService = fakeas.NewFakeV1Service()

	factory = NewFactory(settings, platform, blobstore, taskService, notifier, applier, compiler, monitor, specService)
	return
}
