package app

import (
	boshagent "bosh/agent"
	boshaction "bosh/agent/action"
	boshalert "bosh/agent/alert"
	boshapplier "bosh/agent/applier"
	boshas "bosh/agent/applier/applyspec"
	bc "bosh/agent/applier/bundlecollection"
	ja "bosh/agent/applier/jobapplier"
	pa "bosh/agent/applier/packageapplier"
	boshcomp "bosh/agent/compiler"
	boshdrain "bosh/agent/drain"
	boshtask "bosh/agent/task"
	boshblob "bosh/blobstore"
	boshboot "bosh/bootstrap"
	bosherr "bosh/errors"
	boshinf "bosh/infrastructure"
	boshjobsuper "bosh/jobsupervisor"
	boshmonit "bosh/jobsupervisor/monit"
	boshlog "bosh/logger"
	boshmbus "bosh/mbus"
	boshnotif "bosh/notification"
	boshplatform "bosh/platform"
	boshdirs "bosh/settings/directories"
	"path/filepath"
	"time"
)

type app struct {
	logger boshlog.Logger
}

func New(logger boshlog.Logger) (app app) {
	app.logger = logger
	return
}

func (app app) Run(args []string) (err error) {
	opts, err := ParseOptions(args)
	if err != nil {
		err = bosherr.WrapError(err, "Parsing options")
		return
	}

	dirProvider := boshdirs.NewDirectoriesProvider(opts.BaseDirectory)

	platformProvider := boshplatform.NewProvider(app.logger, dirProvider)
	platform, err := platformProvider.Get(opts.PlatformName)
	if err != nil {
		err = bosherr.WrapError(err, "Getting platform")
		return
	}

	infProvider := boshinf.NewProvider(app.logger, platform)
	infrastructure, err := infProvider.Get(opts.InfrastructureName)
	if err != nil {
		err = bosherr.WrapError(err, "Getting infrastructure")
		return
	}

	boot := boshboot.New(infrastructure, platform, dirProvider)
	settingsService, err := boot.Run()
	if err != nil {
		err = bosherr.WrapError(err, "Running bootstrap")
		return
	}

	mbusHandlerProvider := boshmbus.NewHandlerProvider(settingsService, app.logger)
	mbusHandler, err := mbusHandlerProvider.Get(platform, dirProvider)
	if err != nil {
		err = bosherr.WrapError(err, "Getting mbus handler")
		return
	}

	blobstoreProvider := boshblob.NewProvider(platform, dirProvider)
	blobstore, err := blobstoreProvider.Get(settingsService.GetBlobstore())
	if err != nil {
		err = bosherr.WrapError(err, "Getting blobstore")
		return
	}

	monitClientProvider := boshmonit.NewProvider(platform)
	monitClient, err := monitClientProvider.Get()
	if err != nil {
		err = bosherr.WrapError(err, "Getting monit client")
		return
	}

	jobSupervisorProvider := boshjobsuper.NewProvider(platform, monitClient, app.logger, dirProvider)
	jobSupervisor, err := jobSupervisorProvider.Get(opts.JobSupervisor)
	if err != nil {
		err = bosherr.WrapError(err, "Getting job supervisor")
		return
	}

	notifier := boshnotif.NewNotifier(mbusHandler)

	installPath := filepath.Join(dirProvider.BaseDir(), "data")

	jobsBc := bc.NewFileBundleCollection(installPath, dirProvider.BaseDir(), "jobs", platform.GetFs())

	jobApplier := ja.NewRenderedJobApplier(
		jobsBc,
		blobstore,
		platform.GetCompressor(),
		jobSupervisor,
	)

	packagesBc := bc.NewFileBundleCollection(installPath, dirProvider.BaseDir(), "packages", platform.GetFs())

	packageApplier := pa.NewConcretePackageApplier(
		packagesBc,
		blobstore,
		platform.GetCompressor(),
	)

	applier := boshapplier.NewConcreteApplier(jobApplier, packageApplier, platform, jobSupervisor, dirProvider)

	compiler := boshcomp.NewConcreteCompiler(
		platform.GetCompressor(),
		blobstore,
		platform.GetFs(),
		platform.GetRunner(),
		dirProvider,
		packageApplier,
		packagesBc,
	)

	taskService := boshtask.NewAsyncTaskService(app.logger)

	specFilePath := filepath.Join(dirProvider.BaseDir(), "bosh", "spec.json")
	specService := boshas.NewConcreteV1Service(platform.GetFs(), specFilePath)
	drainScriptProvider := boshdrain.NewConcreteDrainScriptProvider(platform.GetRunner(), platform.GetFs(), dirProvider)

	actionFactory := boshaction.NewFactory(
		settingsService,
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
	actionRunner := boshaction.NewRunner()
	actionDispatcher := boshagent.NewActionDispatcher(app.logger, taskService, actionFactory, actionRunner)
	alertBuilder := boshalert.NewBuilder(settingsService, app.logger)

	agent := boshagent.New(app.logger, mbusHandler, platform, actionDispatcher, alertBuilder, jobSupervisor, time.Minute)
	err = agent.Run()
	if err != nil {
		err = bosherr.WrapError(err, "Running agent")
	}
	return
}
