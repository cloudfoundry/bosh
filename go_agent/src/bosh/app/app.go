package app

import (
	"path/filepath"
	"time"

	boshagent "bosh/agent"
	boshaction "bosh/agent/action"
	boshalert "bosh/agent/alert"
	boshapplier "bosh/agent/applier"
	boshas "bosh/agent/applier/applyspec"
	boshbc "bosh/agent/applier/bundlecollection"
	boshja "bosh/agent/applier/jobapplier"
	boshpa "bosh/agent/applier/packageapplier"
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
	boshsyslog "bosh/syslog"
	boshsys "bosh/system"
	boshtime "bosh/time"
	boshuuid "bosh/uuid"
)

type app struct {
	logger         boshlog.Logger
	agent          boshagent.Agent
	platform       boshplatform.Platform
	infrastructure boshinf.Infrastructure
}

func New(logger boshlog.Logger) app {
	return app{logger: logger}
}

func (app *app) Setup(args []string) error {
	opts, err := ParseOptions(args)
	if err != nil {
		return bosherr.WrapError(err, "Parsing options")
	}

	config, err := app.loadConfig(opts.ConfigPath)
	if err != nil {
		return bosherr.WrapError(err, "Loading config")
	}

	dirProvider := boshdirs.NewDirectoriesProvider(opts.BaseDirectory)

	platformProvider := boshplatform.NewProvider(app.logger, dirProvider, config.Platform)

	app.platform, err = platformProvider.Get(opts.PlatformName)
	if err != nil {
		return bosherr.WrapError(err, "Getting platform")
	}

	infProvider := boshinf.NewProvider(app.logger, app.platform)
	app.infrastructure, err = infProvider.Get(opts.InfrastructureName)

	app.platform.SetDevicePathResolver(app.infrastructure.GetDevicePathResolver())

	if err != nil {
		return bosherr.WrapError(err, "Getting infrastructure")
	}

	settingsServiceProvider := boshsettings.NewServiceProvider()

	boot := boshboot.New(
		app.infrastructure,
		app.platform,
		dirProvider,
		settingsServiceProvider,
		app.logger,
	)

	settingsService, err := boot.Run()
	if err != nil {
		return bosherr.WrapError(err, "Running bootstrap")
	}

	mbusHandlerProvider := boshmbus.NewHandlerProvider(settingsService, app.logger)

	mbusHandler, err := mbusHandlerProvider.Get(app.platform, dirProvider)
	if err != nil {
		return bosherr.WrapError(err, "Getting mbus handler")
	}

	blobstoreProvider := boshblob.NewProvider(app.platform, dirProvider, app.logger)

	blobstore, err := blobstoreProvider.Get(settingsService.GetSettings().Blobstore)
	if err != nil {
		return bosherr.WrapError(err, "Getting blobstore")
	}

	monitClientProvider := boshmonit.NewProvider(app.platform, app.logger)

	monitClient, err := monitClientProvider.Get()
	if err != nil {
		return bosherr.WrapError(err, "Getting monit client")
	}

	jobSupervisorProvider := boshjobsuper.NewProvider(
		app.platform,
		monitClient,
		app.logger,
		dirProvider,
		mbusHandler,
	)

	jobSupervisor, err := jobSupervisorProvider.Get(opts.JobSupervisor)
	if err != nil {
		return bosherr.WrapError(err, "Getting job supervisor")
	}

	notifier := boshnotif.NewNotifier(mbusHandler)

	applier, compiler := app.buildApplierAndCompiler(dirProvider, blobstore, jobSupervisor)

	uuidGen := boshuuid.NewGenerator()

	timeService := boshtime.NewConcreteService()

	taskService := boshtask.NewAsyncTaskService(uuidGen, app.logger)

	taskManager := boshtask.NewManagerProvider().NewManager(
		app.logger,
		app.platform.GetFs(),
		dirProvider.BoshDir(),
	)

	specFilePath := filepath.Join(dirProvider.BoshDir(), "spec.json")
	specService := boshas.NewConcreteV1Service(
		app.platform.GetFs(),
		specFilePath,
	)

	drainScriptProvider := boshdrain.NewConcreteDrainScriptProvider(
		app.platform.GetRunner(),
		app.platform.GetFs(),
		dirProvider,
	)

	actionFactory := boshaction.NewFactory(
		settingsService,
		app.platform,
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

	actionDispatcher := boshagent.NewActionDispatcher(
		app.logger,
		taskService,
		taskManager,
		actionFactory,
		actionRunner,
	)

	alertBuilder := boshalert.NewBuilder(settingsService, app.logger)

	alertSender := boshagent.NewConcreteAlertSender(
		mbusHandler,
		alertBuilder,
		uuidGen,
		timeService,
	)

	syslogServer := boshsyslog.NewServer(33331, app.logger)

	app.agent = boshagent.New(
		app.logger,
		mbusHandler,
		app.platform,
		actionDispatcher,
		alertSender,
		jobSupervisor,
		specService,
		syslogServer,
		time.Minute,
	)

	return nil
}

func (app *app) Run() error {
	err := app.agent.Run()
	if err != nil {
		return bosherr.WrapError(err, "Running agent")
	}
	return nil
}

func (app *app) GetPlatform() boshplatform.Platform {
	return app.platform
}

func (app *app) GetInfrastructure() boshinf.Infrastructure {
	return app.infrastructure
}

func (app *app) buildApplierAndCompiler(
	dirProvider boshdirs.DirectoriesProvider,
	blobstore boshblob.Blobstore,
	jobSupervisor boshjobsuper.JobSupervisor,
) (boshapplier.Applier, boshcomp.Compiler) {
	jobsBc := boshbc.NewFileBundleCollection(
		dirProvider.DataDir(),
		dirProvider.BaseDir(),
		"jobs",
		app.platform.GetFs(),
		app.logger,
	)

	packageApplierProvider := boshpa.NewConcretePackageApplierProvider(
		dirProvider.DataDir(),
		dirProvider.BaseDir(),
		dirProvider.JobsDir(),
		"packages",
		blobstore,
		app.platform.GetCompressor(),
		app.platform.GetFs(),
		app.logger,
	)

	jobApplier := boshja.NewRenderedJobApplier(
		jobsBc,
		jobSupervisor,
		packageApplierProvider,
		blobstore,
		app.platform.GetCompressor(),
		app.platform.GetFs(),
		app.logger,
	)

	applier := boshapplier.NewConcreteApplier(
		jobApplier,
		packageApplierProvider.Root(),
		app.platform,
		jobSupervisor,
		dirProvider,
	)

	compiler := boshcomp.NewConcreteCompiler(
		app.platform.GetCompressor(),
		blobstore,
		app.platform.GetFs(),
		app.platform.GetRunner(),
		dirProvider,
		packageApplierProvider.Root(),
		packageApplierProvider.RootBundleCollection(),
	)

	return applier, compiler
}

func (app *app) loadConfig(path string) (Config, error) {
	// Use one off copy of file system to read configuration file
	fs := boshsys.NewOsFileSystem(app.logger)
	return LoadConfigFromPath(fs, path)
}
