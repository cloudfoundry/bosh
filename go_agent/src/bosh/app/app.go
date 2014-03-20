package app

import (
	"path/filepath"
	"time"

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
	boshsettings "bosh/settings"
	boshdirs "bosh/settings/directories"
	boshuuid "bosh/uuid"
)

type app struct {
	logger         boshlog.Logger
	agent          boshagent.Agent
	platform       boshplatform.Platform
	infrastructure boshinf.Infrastructure
}

func New(logger boshlog.Logger) (app app) {
	app.logger = logger
	return
}

func (app *app) Setup(args []string) (err error) {
	opts, err := ParseOptions(args)
	if err != nil {
		err = bosherr.WrapError(err, "Parsing options")
		return
	}

	dirProvider := boshdirs.NewDirectoriesProvider(opts.BaseDirectory)

	platformProvider := boshplatform.NewProvider(app.logger, dirProvider)
	app.platform, err = platformProvider.Get(opts.PlatformName)
	if err != nil {
		err = bosherr.WrapError(err, "Getting platform")
		return
	}

	infProvider := boshinf.NewProvider(app.logger, app.platform)
	app.infrastructure, err = infProvider.Get(opts.InfrastructureName)

	app.platform.SetDevicePathResolver(app.infrastructure.GetDevicePathResolver())

	if err != nil {
		err = bosherr.WrapError(err, "Getting infrastructure")
		return
	}

	settingsServiceProvider := boshsettings.NewServiceProvider()

	boot := boshboot.New(app.infrastructure, app.platform, dirProvider, settingsServiceProvider)
	settingsService, err := boot.Run()
	if err != nil {
		err = bosherr.WrapError(err, "Running bootstrap")
		return
	}

	mbusHandlerProvider := boshmbus.NewHandlerProvider(settingsService, app.logger)
	mbusHandler, err := mbusHandlerProvider.Get(app.platform, dirProvider)
	if err != nil {
		err = bosherr.WrapError(err, "Getting mbus handler")
		return
	}

	blobstoreProvider := boshblob.NewProvider(app.platform, dirProvider)
	blobstore, err := blobstoreProvider.Get(settingsService.GetBlobstore())
	if err != nil {
		err = bosherr.WrapError(err, "Getting blobstore")
		return
	}

	monitClientProvider := boshmonit.NewProvider(app.platform, app.logger)
	monitClient, err := monitClientProvider.Get()
	if err != nil {
		err = bosherr.WrapError(err, "Getting monit client")
		return
	}

	jobSupervisorProvider := boshjobsuper.NewProvider(app.platform, monitClient, app.logger, dirProvider)
	jobSupervisor, err := jobSupervisorProvider.Get(opts.JobSupervisor)
	if err != nil {
		err = bosherr.WrapError(err, "Getting job supervisor")
		return
	}

	notifier := boshnotif.NewNotifier(mbusHandler)

	installPath := filepath.Join(dirProvider.BaseDir(), "data")

	jobsBc := bc.NewFileBundleCollection(installPath, dirProvider.BaseDir(), "jobs", app.platform.GetFs())

	jobApplier := ja.NewRenderedJobApplier(
		jobsBc,
		blobstore,
		app.platform.GetCompressor(),
		jobSupervisor,
	)

	packagesBc := bc.NewFileBundleCollection(installPath, dirProvider.BaseDir(), "packages", app.platform.GetFs())

	packageApplier := pa.NewConcretePackageApplier(
		packagesBc,
		blobstore,
		app.platform.GetCompressor(),
	)

	applier := boshapplier.NewConcreteApplier(jobApplier, packageApplier, app.platform, jobSupervisor, dirProvider)

	compiler := boshcomp.NewConcreteCompiler(
		app.platform.GetCompressor(),
		blobstore,
		app.platform.GetFs(),
		app.platform.GetRunner(),
		dirProvider,
		packageApplier,
		packagesBc,
	)

	uuidGen := boshuuid.NewGenerator()

	taskService := boshtask.NewAsyncTaskService(uuidGen, app.logger)

	taskManager := boshtask.NewManagerProvider().NewManager(
		app.logger,
		app.platform.GetFs(),
		dirProvider.BoshDir(),
	)

	specFilePath := filepath.Join(dirProvider.BoshDir(), "spec.json")
	specService := boshas.NewConcreteV1Service(app.platform.GetFs(), specFilePath)
	drainScriptProvider := boshdrain.NewConcreteDrainScriptProvider(app.platform.GetRunner(), app.platform.GetFs(), dirProvider)

	actionFactory := boshaction.NewFactory(
		settingsService,
		app.platform,
		app.infrastructure,
		blobstore,
		taskService,
		notifier,
		applier,
		compiler,
		jobSupervisor,
		specService,
		drainScriptProvider,
		app.logger,
	)
	actionRunner := boshaction.NewRunner()
	actionDispatcher := boshagent.NewActionDispatcher(app.logger, taskService, taskManager, actionFactory, actionRunner)
	alertBuilder := boshalert.NewBuilder(settingsService, app.logger)

	app.agent = boshagent.New(app.logger, mbusHandler, app.platform, actionDispatcher, alertBuilder, jobSupervisor, time.Minute)

	return
}

func (app *app) Run() (err error) {
	err = app.agent.Run()
	if err != nil {
		err = bosherr.WrapError(err, "Running agent")
	}
	return
}

func (app *app) GetPlatform() boshplatform.Platform {
	return app.platform
}

func (app *app) GetInfrastructure() boshinf.Infrastructure {
	return app.infrastructure
}
