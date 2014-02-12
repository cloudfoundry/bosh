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
	. "github.com/onsi/ginkgo"
	"github.com/stretchr/testify/assert"
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
func init() {
	Describe("Testing with Ginkgo", func() {
		It("new factory", func() {
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
				assert.NoError(GinkgoT(), err)
				assert.NotNil(GinkgoT(), action)
			}

			action, err := factory.Create("gobberish")
			assert.Error(GinkgoT(), err)
			assert.Nil(GinkgoT(), action)
		})
		It("new factory apply", func() {

			deps, factory := buildFactory()
			action, err := factory.Create("apply")
			assert.NoError(GinkgoT(), err)
			assert.NotNil(GinkgoT(), action)
			assert.Equal(GinkgoT(), NewApply(deps.applier, deps.specService), action)
		})
		It("new factory drain", func() {

			deps, factory := buildFactory()
			action, err := factory.Create("drain")
			assert.NoError(GinkgoT(), err)
			assert.NotNil(GinkgoT(), action)
			assert.Equal(GinkgoT(), NewDrain(deps.notifier, deps.specService, deps.drainScriptProvider), action)
		})
		It("new factory fetch logs", func() {

			deps, factory := buildFactory()
			action, err := factory.Create("fetch_logs")
			assert.NoError(GinkgoT(), err)
			assert.NotNil(GinkgoT(), action)
			assert.Equal(GinkgoT(), NewLogs(deps.platform.GetCompressor(), deps.platform.GetCopier(), deps.blobstore, deps.platform.GetDirProvider()), action)
		})
		It("new factory get task", func() {

			deps, factory := buildFactory()
			action, err := factory.Create("get_task")
			assert.NoError(GinkgoT(), err)
			assert.NotNil(GinkgoT(), action)
			assert.Equal(GinkgoT(), NewGetTask(deps.taskService), action)
		})
		It("new factory get state", func() {

			deps, factory := buildFactory()
			ntpService := boshntp.NewConcreteService(deps.platform.GetFs(), deps.platform.GetDirProvider())
			action, err := factory.Create("get_state")
			assert.NoError(GinkgoT(), err)
			assert.NotNil(GinkgoT(), action)
			assert.Equal(GinkgoT(), NewGetState(deps.settings, deps.specService, deps.jobSupervisor, deps.platform.GetVitalsService(), ntpService), action)
		})
		It("new factory list disk", func() {

			deps, factory := buildFactory()
			action, err := factory.Create("list_disk")
			assert.NoError(GinkgoT(), err)
			assert.NotNil(GinkgoT(), action)
			assert.Equal(GinkgoT(), NewListDisk(deps.settings, deps.platform), action)
		})
		It("new factory migrate disk", func() {

			deps, factory := buildFactory()
			action, err := factory.Create("migrate_disk")
			assert.NoError(GinkgoT(), err)
			assert.NotNil(GinkgoT(), action)
			assert.Equal(GinkgoT(), NewMigrateDisk(deps.platform, deps.platform.GetDirProvider()), action)
		})
		It("new factory mount disk", func() {

			deps, factory := buildFactory()
			action, err := factory.Create("mount_disk")
			assert.NoError(GinkgoT(), err)
			assert.NotNil(GinkgoT(), action)
			assert.Equal(GinkgoT(), NewMountDisk(deps.settings, deps.platform, deps.platform.GetDirProvider()), action)
		})
		It("new factory ssh", func() {

			deps, factory := buildFactory()
			action, err := factory.Create("ssh")
			assert.NoError(GinkgoT(), err)
			assert.NotNil(GinkgoT(), action)
			assert.Equal(GinkgoT(), NewSsh(deps.settings, deps.platform, deps.platform.GetDirProvider()), action)
		})
		It("new factory start", func() {

			deps, factory := buildFactory()
			action, err := factory.Create("start")
			assert.NoError(GinkgoT(), err)
			assert.NotNil(GinkgoT(), action)
			assert.Equal(GinkgoT(), NewStart(deps.jobSupervisor), action)
		})
		It("new factory unmount disk", func() {

			deps, factory := buildFactory()
			action, err := factory.Create("unmount_disk")
			assert.NoError(GinkgoT(), err)
			assert.NotNil(GinkgoT(), action)
			assert.Equal(GinkgoT(), NewUnmountDisk(deps.settings, deps.platform), action)
		})
		It("new factory compile package", func() {

			deps, factory := buildFactory()
			action, err := factory.Create("compile_package")
			assert.NoError(GinkgoT(), err)
			assert.NotNil(GinkgoT(), action)
			assert.Equal(GinkgoT(), NewCompilePackage(deps.compiler), action)
		})
	})
}
