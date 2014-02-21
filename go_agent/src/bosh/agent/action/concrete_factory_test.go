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

func init() {
	Describe("Testing with Ginkgo", func() {
		var (
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
			factory             Factory
		)

		BeforeEach(func() {
			settings = &fakesettings.FakeSettingsService{}
			platform = fakeplatform.NewFakePlatform()
			blobstore = &fakeblobstore.FakeBlobstore{}
			taskService = &faketask.FakeService{}
			notifier = fakenotif.NewFakeNotifier()
			applier = fakeappl.NewFakeApplier()
			compiler = fakecomp.NewFakeCompiler()
			jobSupervisor = fakejobsuper.NewFakeJobSupervisor()
			specService = fakeas.NewFakeV1Service()
			drainScriptProvider = boshdrain.NewConcreteDrainScriptProvider(nil, nil, platform.GetDirProvider())

		})

		JustBeforeEach(func() {
			factory = NewFactory(
				settings,
				platform,
				blobstore,
				taskService,
				notifier,
				applier,
				compiler,
				jobSupervisor,
				specService,
				drainScriptProvider,
			)
		})

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
			action, err := factory.Create("apply")
			assert.NoError(GinkgoT(), err)
			assert.NotNil(GinkgoT(), action)
			assert.Equal(GinkgoT(), NewApply(applier, specService), action)
		})

		It("new factory drain", func() {
			action, err := factory.Create("drain")
			assert.NoError(GinkgoT(), err)
			assert.NotNil(GinkgoT(), action)
			assert.Equal(GinkgoT(), NewDrain(notifier, specService, drainScriptProvider), action)
		})

		It("new factory fetch logs", func() {
			action, err := factory.Create("fetch_logs")
			assert.NoError(GinkgoT(), err)
			assert.NotNil(GinkgoT(), action)
			assert.Equal(GinkgoT(), NewLogs(platform.GetCompressor(), platform.GetCopier(), blobstore, platform.GetDirProvider()), action)
		})

		It("new factory get task", func() {
			action, err := factory.Create("get_task")
			assert.NoError(GinkgoT(), err)
			assert.NotNil(GinkgoT(), action)
			assert.Equal(GinkgoT(), NewGetTask(taskService), action)
		})

		It("new factory get state", func() {
			ntpService := boshntp.NewConcreteService(platform.GetFs(), platform.GetDirProvider())
			action, err := factory.Create("get_state")
			assert.NoError(GinkgoT(), err)
			assert.NotNil(GinkgoT(), action)
			assert.Equal(GinkgoT(), NewGetState(settings, specService, jobSupervisor, platform.GetVitalsService(), ntpService), action)
		})

		It("new factory list disk", func() {
			action, err := factory.Create("list_disk")
			assert.NoError(GinkgoT(), err)
			assert.NotNil(GinkgoT(), action)
			assert.Equal(GinkgoT(), NewListDisk(settings, platform), action)
		})

		It("new factory migrate disk", func() {
			action, err := factory.Create("migrate_disk")
			assert.NoError(GinkgoT(), err)
			assert.NotNil(GinkgoT(), action)
			assert.Equal(GinkgoT(), NewMigrateDisk(platform, platform.GetDirProvider()), action)
		})

		It("new factory mount disk", func() {
			action, err := factory.Create("mount_disk")
			assert.NoError(GinkgoT(), err)
			assert.NotNil(GinkgoT(), action)
			assert.Equal(GinkgoT(), NewMountDisk(settings, platform, platform.GetDirProvider()), action)
		})

		It("new factory ssh", func() {
			action, err := factory.Create("ssh")
			assert.NoError(GinkgoT(), err)
			assert.NotNil(GinkgoT(), action)
			assert.Equal(GinkgoT(), NewSsh(settings, platform, platform.GetDirProvider()), action)
		})

		It("new factory start", func() {
			action, err := factory.Create("start")
			assert.NoError(GinkgoT(), err)
			assert.NotNil(GinkgoT(), action)
			assert.Equal(GinkgoT(), NewStart(jobSupervisor), action)
		})

		It("new factory unmount disk", func() {
			action, err := factory.Create("unmount_disk")
			assert.NoError(GinkgoT(), err)
			assert.NotNil(GinkgoT(), action)
			assert.Equal(GinkgoT(), NewUnmountDisk(settings, platform), action)
		})

		It("new factory compile package", func() {
			action, err := factory.Create("compile_package")
			assert.NoError(GinkgoT(), err)
			assert.NotNil(GinkgoT(), action)
			assert.Equal(GinkgoT(), NewCompilePackage(compiler), action)
		})
	})
}
