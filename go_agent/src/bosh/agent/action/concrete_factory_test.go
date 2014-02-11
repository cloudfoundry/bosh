package action_test

import (
	. "bosh/agent/action"
	fakeas "bosh/agent/applier/applyspec/fakes"
	fakeappl "bosh/agent/applier/fakes"
	fakecomp "bosh/agent/compiler/fakes"
	boshdrain "bosh/agent/drain"
	faketask "bosh/agent/task/fakes"
	fakeblobstore "bosh/blobstore/fakes"
	fakejobsuper "bosh/jobsupervisor/fakes"
	fakenotif "bosh/notification/fakes"
	fakeplatform "bosh/platform/fakes"
	boshntp "bosh/platform/ntp"
	fakesettings "bosh/settings/fakes"
	"github.com/stretchr/testify/assert"
	"testing"
)

type concreteFactoryDependencies struct {
	settings            *fakesettings.FakeSettingsService
	platform            *fakeplatform.FakePlatform
	blobstore           *fakeblobstore.FakeBlobstore
	taskService         *faketask.FakeService
	notifier            *fakenotif.FakeNotifier
	applier             *fakeappl.FakeApplier
	compiler            *fakecomp.FakeCompiler
	jobSupervisor       *fakejobsuper.FakeJobSupervisor
	specService         *fakeas.FakeV1Service
	drainScriptProvider boshdrain.DrainScriptProvider
}

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
		"release_apply_spec",
	}

	_, factory := buildFactory()

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
	deps, factory := buildFactory()
	action, err := factory.Create("apply")
	assert.NoError(t, err)
	assert.NotNil(t, action)
	assert.Equal(t, NewApply(deps.applier, deps.specService), action)
}

func TestNewFactoryDrain(t *testing.T) {
	deps, factory := buildFactory()
	action, err := factory.Create("drain")
	assert.NoError(t, err)
	assert.NotNil(t, action)
	assert.Equal(t, NewDrain(deps.notifier, deps.specService, deps.drainScriptProvider), action)
}

func TestNewFactoryFetchLogs(t *testing.T) {
	deps, factory := buildFactory()
	action, err := factory.Create("fetch_logs")
	assert.NoError(t, err)
	assert.NotNil(t, action)
	assert.Equal(t, NewLogs(deps.platform.GetCompressor(), deps.platform.GetCopier(), deps.blobstore, deps.platform.GetDirProvider()), action)
}

func TestNewFactoryGetTask(t *testing.T) {
	deps, factory := buildFactory()
	action, err := factory.Create("get_task")
	assert.NoError(t, err)
	assert.NotNil(t, action)
	assert.Equal(t, NewGetTask(deps.taskService), action)
}

func TestNewFactoryGetState(t *testing.T) {
	deps, factory := buildFactory()
	ntpService := boshntp.NewConcreteService(deps.platform.GetFs(), deps.platform.GetDirProvider())
	action, err := factory.Create("get_state")
	assert.NoError(t, err)
	assert.NotNil(t, action)
	assert.Equal(t, NewGetState(deps.settings, deps.specService, deps.jobSupervisor, deps.platform.GetVitalsService(), ntpService), action)
}

func TestNewFactoryListDisk(t *testing.T) {
	deps, factory := buildFactory()
	action, err := factory.Create("list_disk")
	assert.NoError(t, err)
	assert.NotNil(t, action)
	assert.Equal(t, NewListDisk(deps.settings, deps.platform), action)
}

func TestNewFactoryMigrateDisk(t *testing.T) {
	deps, factory := buildFactory()
	action, err := factory.Create("migrate_disk")
	assert.NoError(t, err)
	assert.NotNil(t, action)
	assert.Equal(t, NewMigrateDisk(deps.platform, deps.platform.GetDirProvider()), action)
}

func TestNewFactoryMountDisk(t *testing.T) {
	deps, factory := buildFactory()
	action, err := factory.Create("mount_disk")
	assert.NoError(t, err)
	assert.NotNil(t, action)
	assert.Equal(t, NewMountDisk(deps.settings, deps.platform, deps.platform.GetDirProvider()), action)
}

func TestNewFactorySsh(t *testing.T) {
	deps, factory := buildFactory()
	action, err := factory.Create("ssh")
	assert.NoError(t, err)
	assert.NotNil(t, action)
	assert.Equal(t, NewSsh(deps.settings, deps.platform, deps.platform.GetDirProvider()), action)
}

func TestNewFactoryStart(t *testing.T) {
	deps, factory := buildFactory()
	action, err := factory.Create("start")
	assert.NoError(t, err)
	assert.NotNil(t, action)
	assert.Equal(t, NewStart(deps.jobSupervisor), action)
}

func TestNewFactoryUnmountDisk(t *testing.T) {
	deps, factory := buildFactory()
	action, err := factory.Create("unmount_disk")
	assert.NoError(t, err)
	assert.NotNil(t, action)
	assert.Equal(t, NewUnmountDisk(deps.settings, deps.platform), action)
}

func TestNewFactoryCompilePackage(t *testing.T) {
	deps, factory := buildFactory()
	action, err := factory.Create("compile_package")
	assert.NoError(t, err)
	assert.NotNil(t, action)
	assert.Equal(t, NewCompilePackage(deps.compiler), action)
}

func buildFactory() (
	deps concreteFactoryDependencies,
	factory Factory) {

	deps.settings = &fakesettings.FakeSettingsService{}
	deps.platform = fakeplatform.NewFakePlatform()
	deps.blobstore = &fakeblobstore.FakeBlobstore{}
	deps.taskService = &faketask.FakeService{}
	deps.notifier = fakenotif.NewFakeNotifier()
	deps.applier = fakeappl.NewFakeApplier()
	deps.compiler = fakecomp.NewFakeCompiler()
	deps.jobSupervisor = fakejobsuper.NewFakeJobSupervisor()
	deps.specService = fakeas.NewFakeV1Service()
	deps.drainScriptProvider = boshdrain.NewConcreteDrainScriptProvider(nil, nil, deps.platform.GetDirProvider())

	factory = NewFactory(
		deps.settings,
		deps.platform,
		deps.blobstore,
		deps.taskService,
		deps.notifier,
		deps.applier,
		deps.compiler,
		deps.jobSupervisor,
		deps.specService,
		deps.drainScriptProvider,
	)
	return
}
