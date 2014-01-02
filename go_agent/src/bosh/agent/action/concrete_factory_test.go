package action

import (
	fakeas "bosh/agent/applier/applyspec/fakes"
	fakeappl "bosh/agent/applier/fakes"
	fakecomp "bosh/agent/compiler/fakes"
	boshdrain "bosh/agent/drain"
	faketask "bosh/agent/task/fakes"
	fakeblobstore "bosh/blobstore/fakes"
	fakejobsuper "bosh/jobsupervisor/fakes"
	fakenotif "bosh/notification/fakes"
	fakeplatform "bosh/platform/fakes"
	fakestats "bosh/platform/stats/fakes"
	boshdirs "bosh/settings/directories"
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
	dirProvider         boshdirs.DirectoriesProvider
	drainScriptProvider boshdrain.DrainScriptProvider
	statsCollector      *fakestats.FakeStatsCollector
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
	assert.Equal(t, newApply(deps.applier, deps.specService), action)
}

func TestNewFactoryDrain(t *testing.T) {
	deps, factory := buildFactory()
	action, err := factory.Create("drain")
	assert.NoError(t, err)
	assert.NotNil(t, action)
	assert.Equal(t, newDrain(deps.notifier, deps.specService, deps.drainScriptProvider), action)
}

func TestNewFactoryFetchLogs(t *testing.T) {
	deps, factory := buildFactory()
	action, err := factory.Create("fetch_logs")
	assert.NoError(t, err)
	assert.NotNil(t, action)
	assert.Equal(t, newLogs(deps.platform.GetCompressor(), deps.blobstore, deps.dirProvider), action)
}

func TestNewFactoryGetTask(t *testing.T) {
	deps, factory := buildFactory()
	action, err := factory.Create("get_task")
	assert.NoError(t, err)
	assert.NotNil(t, action)
	assert.Equal(t, newGetTask(deps.taskService), action)
}

func TestNewFactoryGetState(t *testing.T) {
	deps, factory := buildFactory()
	action, err := factory.Create("get_state")
	assert.NoError(t, err)
	assert.NotNil(t, action)
	assert.Equal(t, newGetState(deps.settings, deps.specService, deps.jobSupervisor, deps.statsCollector, deps.dirProvider), action)
}

func TestNewFactoryListDisk(t *testing.T) {
	deps, factory := buildFactory()
	action, err := factory.Create("list_disk")
	assert.NoError(t, err)
	assert.NotNil(t, action)
	assert.Equal(t, newListDisk(deps.settings, deps.platform), action)
}

func TestNewFactoryMigrateDisk(t *testing.T) {
	deps, factory := buildFactory()
	action, err := factory.Create("migrate_disk")
	assert.NoError(t, err)
	assert.NotNil(t, action)
	assert.Equal(t, newMigrateDisk(deps.settings, deps.platform, deps.dirProvider), action)
}

func TestNewFactoryMountDisk(t *testing.T) {
	deps, factory := buildFactory()
	action, err := factory.Create("mount_disk")
	assert.NoError(t, err)
	assert.NotNil(t, action)
	assert.Equal(t, newMountDisk(deps.settings, deps.platform, deps.dirProvider), action)
}

func TestNewFactorySsh(t *testing.T) {
	deps, factory := buildFactory()
	action, err := factory.Create("ssh")
	assert.NoError(t, err)
	assert.NotNil(t, action)
	assert.Equal(t, newSsh(deps.settings, deps.platform, deps.dirProvider), action)
}

func TestNewFactoryStart(t *testing.T) {
	deps, factory := buildFactory()
	action, err := factory.Create("start")
	assert.NoError(t, err)
	assert.NotNil(t, action)
	assert.Equal(t, newStart(deps.jobSupervisor), action)
}

func TestNewFactoryUnmountDisk(t *testing.T) {
	deps, factory := buildFactory()
	action, err := factory.Create("unmount_disk")
	assert.NoError(t, err)
	assert.NotNil(t, action)
	assert.Equal(t, newUnmountDisk(deps.settings, deps.platform), action)
}

func TestNewFactoryCompilePackage(t *testing.T) {
	deps, factory := buildFactory()
	action, err := factory.Create("compile_package")
	assert.NoError(t, err)
	assert.NotNil(t, action)
	assert.Equal(t, newCompilePackage(deps.compiler), action)
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
	deps.dirProvider = boshdirs.NewDirectoriesProvider("/foo")
	deps.drainScriptProvider = boshdrain.NewConcreteDrainScriptProvider(nil, nil, deps.dirProvider)
	deps.statsCollector = &fakestats.FakeStatsCollector{}

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
		deps.dirProvider,
		deps.drainScriptProvider,
	)
	return
}
