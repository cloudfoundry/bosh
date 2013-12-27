package app

import (
	boshagent "bosh/agent"
	boshaction "bosh/agent/action"
	boshappl "bosh/agent/applier"
	boshas "bosh/agent/applier/applyspec"
	boshcomp "bosh/agent/compiler"
	boshdrain "bosh/agent/drain"
	boshtask "bosh/agent/task"
	boshblob "bosh/blobstore"
	boshboot "bosh/bootstrap"
	bosherr "bosh/errors"
	boshinf "bosh/infrastructure"
	boshlog "bosh/logger"
	boshmbus "bosh/mbus"
	boshmon "bosh/monitor"
	boshmonit "bosh/monitor/monit"
	boshnotif "bosh/notification"
	boshplatform "bosh/platform"
	boshdirs "bosh/settings/directories"
	"flag"
	"io/ioutil"
	"path/filepath"
)

type app struct {
	logger boshlog.Logger
}

type options struct {
	InfrastructureName string
	PlatformName       string
	BaseDirectory      string
}

func New(logger boshlog.Logger) (app app) {
	app.logger = logger
	return
}

func (app app) Run(args []string) (err error) {
	opts, err := parseOptions(args)
	if err != nil {
		err = bosherr.WrapError(err, "Parsing options")
		return
	}

	dirProvider := boshdirs.NewDirectoriesProvider(opts.BaseDirectory)

	infProvider := boshinf.NewProvider(app.logger)
	infrastructure, err := infProvider.Get(opts.InfrastructureName)
	if err != nil {
		err = bosherr.WrapError(err, "Getting infrastructure")
		return
	}

	platformProvider := boshplatform.NewProvider(app.logger, dirProvider)
	platform, err := platformProvider.Get(opts.PlatformName)
	if err != nil {
		err = bosherr.WrapError(err, "Getting platform")
		return
	}

	boot := boshboot.New(infrastructure, platform, dirProvider)
	settingsService, err := boot.Run()
	if err != nil {
		err = bosherr.WrapError(err, "Running bootstrap")
		return
	}

	mbusHandlerProvider := boshmbus.NewHandlerProvider(settingsService, app.logger)
	mbusHandler, err := mbusHandlerProvider.Get()
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

	monitor := boshmon.NewMonit(platform.GetFs(), platform.GetRunner(), monitClient, app.logger)
	notifier := boshnotif.NewNotifier(mbusHandler)
	applier := boshappl.NewApplierProvider(platform, blobstore, monitor, dirProvider).Get()
	compiler := boshcomp.NewCompilerProvider(platform, blobstore, dirProvider).Get()

	taskService := boshtask.NewAsyncTaskService(app.logger)

	specFilePath := filepath.Join(dirProvider.BaseDir(), "bosh", "spec.json")
	specService := boshas.NewConcreteV1Service(platform.GetFs(), specFilePath)
	drainScriptProvider := boshdrain.NewDrainScriptProvider(platform.GetRunner(), platform.GetFs(), dirProvider)

	actionFactory := boshaction.NewFactory(
		settingsService,
		platform,
		blobstore,
		taskService,
		notifier,
		applier,
		compiler,
		monitor,
		specService,
		dirProvider,
		drainScriptProvider,
	)
	actionRunner := boshaction.NewRunner()
	actionDispatcher := boshagent.NewActionDispatcher(app.logger, taskService, actionFactory, actionRunner)

	agent := boshagent.New(settingsService, app.logger, mbusHandler, platform, actionDispatcher)
	err = agent.Run()
	if err != nil {
		err = bosherr.WrapError(err, "Running agent")
	}
	return
}

func parseOptions(args []string) (opts options, err error) {
	flagSet := flag.NewFlagSet("bosh-agent-args", flag.ContinueOnError)
	flagSet.SetOutput(ioutil.Discard)
	flagSet.StringVar(&opts.InfrastructureName, "I", "", "Set Infrastructure")
	flagSet.StringVar(&opts.PlatformName, "P", "", "Set Platform")
	flagSet.StringVar(&opts.BaseDirectory, "B", "/var/vcap", "Set Base Directory")

	err = flagSet.Parse(args[1:])
	return
}
