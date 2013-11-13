package app

import (
	boshagent "bosh/agent"
	boshaction "bosh/agent/action"
	boshtask "bosh/agent/task"
	boshboot "bosh/bootstrap"
	boshinf "bosh/infrastructure"
	boshmbus "bosh/mbus"
	boshplatform "bosh/platform"
	boshsys "bosh/system"
	"flag"
	"io/ioutil"
)

type App struct {
}

type options struct {
	InfrastructureName string
	PlatformName       string
}

func New() (app App) {
	return
}

func (app App) Run(args []string) (err error) {
	fs := boshsys.OsFileSystem{}

	opts, err := parseOptions(args)
	if err != nil {
		return
	}

	infProvider := boshinf.NewProvider()
	infrastructure, err := infProvider.Get(opts.InfrastructureName)
	if err != nil {
		return
	}

	platformProvider := boshplatform.NewProvider(fs)
	platform, err := platformProvider.Get(opts.PlatformName)
	if err != nil {
		return
	}

	boot := boshboot.New(fs, infrastructure, platform)
	settings, err := boot.Run()
	if err != nil {
		return
	}

	mbusHandlerProvider := boshmbus.NewHandlerProvider(settings)
	mbusHandler, err := mbusHandlerProvider.Get()
	if err != nil {
		return
	}

	tasksService := boshtask.NewAsyncTaskService()
	actionFactory := boshaction.NewFactory(fs)
	agent := boshagent.New(settings, mbusHandler, platform, tasksService, actionFactory)
	err = agent.Run()
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
