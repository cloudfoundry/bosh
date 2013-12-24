package app

import (
	boshagent "bosh/agent"
	boshaction "bosh/agent/action"
	boshappl "bosh/agent/applier"
	boshas "bosh/agent/applier/applyspec"
	boshcomp "bosh/agent/compiler"
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
	boshsettings "bosh/settings"
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

	infProvider := boshinf.NewProvider(app.logger)
	infrastructure, err := infProvider.Get(opts.InfrastructureName)
	if err != nil {
		err = bosherr.WrapError(err, "Getting infrastructure")
		return
	}

	platformProvider := boshplatform.NewProvider(app.logger)
	platform, err := platformProvider.Get(opts.PlatformName)
	if err != nil {
		err = bosherr.WrapError(err, "Getting platform")
		return
	}

	boot := boshboot.New(infrastructure, platform)
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

	blobstoreProvider := boshblob.NewProvider(platform)
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
	applier := boshappl.NewApplierProvider(platform, blobstore, monitor).Get()
	compiler := boshcomp.NewCompilerProvider(platform, blobstore).Get()

	taskService := boshtask.NewAsyncTaskService(app.logger)

	specFilePath := filepath.Join(boshsettings.VCAP_BASE_DIR, "bosh", "spec.json")
	specService := boshas.NewConcreteV1Service(platform.GetFs(), specFilePath)
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

	err = flagSet.Parse(args[1:])
	return
}
