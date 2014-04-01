package action_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	. "bosh/agent/action"
	fakeas "bosh/agent/applier/applyspec/fakes"
	fakeappl "bosh/agent/applier/fakes"
	fakecomp "bosh/agent/compiler/fakes"
	boshdrain "bosh/agent/drain"
	faketask "bosh/agent/task/fakes"
	fakeblobstore "bosh/blobstore/fakes"
	fakeinfrastructure "bosh/infrastructure/fakes"
	fakejobsuper "bosh/jobsupervisor/fakes"
	boshlog "bosh/logger"
	fakenotif "bosh/notification/fakes"
	fakeplatform "bosh/platform/fakes"
	boshntp "bosh/platform/ntp"
	fakesettings "bosh/settings/fakes"
)

func init() {
	Describe("concreteFactory", func() {
		var (
			settings            *fakesettings.FakeSettingsService
			platform            *fakeplatform.FakePlatform
			infrastructure      *fakeinfrastructure.FakeInfrastructure
			blobstore           *fakeblobstore.FakeBlobstore
			taskService         *faketask.FakeService
			notifier            *fakenotif.FakeNotifier
			applier             *fakeappl.FakeApplier
			compiler            *fakecomp.FakeCompiler
			jobSupervisor       *fakejobsuper.FakeJobSupervisor
			specService         *fakeas.FakeV1Service
			drainScriptProvider boshdrain.DrainScriptProvider
			factory             Factory
			logger              boshlog.Logger
		)

		BeforeEach(func() {
			settings = &fakesettings.FakeSettingsService{}
			platform = fakeplatform.NewFakePlatform()
			infrastructure = fakeinfrastructure.NewFakeInfrastructure()
			blobstore = &fakeblobstore.FakeBlobstore{}
			taskService = &faketask.FakeService{}
			notifier = fakenotif.NewFakeNotifier()
			applier = fakeappl.NewFakeApplier()
			compiler = fakecomp.NewFakeCompiler()
			jobSupervisor = fakejobsuper.NewFakeJobSupervisor()
			specService = fakeas.NewFakeV1Service()
			drainScriptProvider = boshdrain.NewConcreteDrainScriptProvider(nil, nil, platform.GetDirProvider())
			logger = boshlog.NewLogger(boshlog.LEVEL_NONE)
		})

		JustBeforeEach(func() {
			factory = NewFactory(
				settings,
				platform,
				infrastructure,
				blobstore,
				taskService,
				notifier,
				applier,
				compiler,
				jobSupervisor,
				specService,
				drainScriptProvider,
				logger,
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
				Expect(err).NotTo(HaveOccurred())
				Expect(action).ToNot(BeNil())
			}

			action, err := factory.Create("gobberish")
			Expect(err).To(HaveOccurred())
			Expect(action).To(BeNil())
		})

		It("apply", func() {
			action, err := factory.Create("apply")
			Expect(err).NotTo(HaveOccurred())
			Expect(action).ToNot(BeNil())
			Expect(NewApply(applier, specService)).To(Equal(action))
		})

		It("drain", func() {
			action, err := factory.Create("drain")
			Expect(err).NotTo(HaveOccurred())
			Expect(action).ToNot(BeNil())
			Expect(NewDrain(notifier, specService, drainScriptProvider, jobSupervisor)).To(Equal(action))
		})

		It("fetch_logs", func() {
			action, err := factory.Create("fetch_logs")
			Expect(err).NotTo(HaveOccurred())
			Expect(action).ToNot(BeNil())
			Expect(NewLogs(platform.GetCompressor(), platform.GetCopier(), blobstore, platform.GetDirProvider())).To(Equal(action))
		})

		It("get_task", func() {
			action, err := factory.Create("get_task")
			Expect(err).NotTo(HaveOccurred())
			Expect(action).ToNot(BeNil())
			Expect(NewGetTask(taskService)).To(Equal(action))
		})

		It("get_state", func() {
			ntpService := boshntp.NewConcreteService(platform.GetFs(), platform.GetDirProvider())
			action, err := factory.Create("get_state")
			Expect(err).NotTo(HaveOccurred())
			Expect(action).ToNot(BeNil())
			Expect(NewGetState(settings, specService, jobSupervisor, platform.GetVitalsService(), ntpService)).To(Equal(action))
		})

		It("list_disk", func() {
			action, err := factory.Create("list_disk")
			Expect(err).NotTo(HaveOccurred())
			Expect(action).ToNot(BeNil())
			Expect(NewListDisk(settings, platform, logger)).To(Equal(action))
		})

		It("migrate_disk", func() {
			action, err := factory.Create("migrate_disk")
			Expect(err).NotTo(HaveOccurred())
			Expect(action).ToNot(BeNil())
			Expect(NewMigrateDisk(platform, platform.GetDirProvider())).To(Equal(action))
		})

		It("mount_disk", func() {
			action, err := factory.Create("mount_disk")
			Expect(err).NotTo(HaveOccurred())
			Expect(action).ToNot(BeNil())
			Expect(NewMountDisk(settings, infrastructure, platform, platform.GetDirProvider())).To(Equal(action))
		})

		It("prepare_network_change", func() {
			action, err := factory.Create("prepare_network_change")
			Expect(err).NotTo(HaveOccurred())
			Expect(action).ToNot(BeNil())
			Expect(NewPrepareNetworkChange(platform.GetFs(), settings)).To(Equal(action))
		})

		It("prepare_configure_networks", func() {
			action, err := factory.Create("prepare_configure_networks")
			Expect(err).NotTo(HaveOccurred())
			Expect(action).ToNot(BeNil())
			Expect(NewPrepareConfigureNetworks(platform.GetFs(), settings)).To(Equal(action))
		})

		It("configure_networks", func() {
			action, err := factory.Create("configure_networks")
			Expect(err).NotTo(HaveOccurred())
			Expect(action).ToNot(BeNil())
			Expect(NewConfigureNetworks()).To(Equal(action))
		})

		It("ssh", func() {
			action, err := factory.Create("ssh")
			Expect(err).NotTo(HaveOccurred())
			Expect(action).ToNot(BeNil())
			Expect(NewSsh(settings, platform, platform.GetDirProvider())).To(Equal(action))
		})

		It("start", func() {
			action, err := factory.Create("start")
			Expect(err).NotTo(HaveOccurred())
			Expect(action).ToNot(BeNil())
			Expect(NewStart(jobSupervisor)).To(Equal(action))
		})

		It("unmount_disk", func() {
			action, err := factory.Create("unmount_disk")
			Expect(err).NotTo(HaveOccurred())
			Expect(action).ToNot(BeNil())
			Expect(NewUnmountDisk(settings, platform)).To(Equal(action))
		})

		It("compile_package", func() {
			action, err := factory.Create("compile_package")
			Expect(err).NotTo(HaveOccurred())
			Expect(action).ToNot(BeNil())
			Expect(NewCompilePackage(compiler)).To(Equal(action))
		})
	})
}
