package app

import (
	"bosh/agent"
	"bosh/bootstrap"
	"bosh/infrastructure"
	"bosh/mbus"
	"bosh/platform"
	"bosh/system"
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
	fs := system.OsFileSystem{}
	runner := system.ExecCmdRunner{}

	opts, err := parseOptions(args)
	if err != nil {
		return
	}

	infProvider := infrastructure.NewProvider()
	infrastructure, err := infProvider.Get(opts.InfrastructureName)
	if err != nil {
		return
	}

	platformProvider := platform.NewProvider(fs, runner)
	platform, err := platformProvider.Get(opts.PlatformName)
	if err != nil {
		return
	}

	b := bootstrap.New(fs, infrastructure, platform)
	s, err := b.Run()
	if err != nil {
		return
	}

	mbusHandlerProvider := mbus.NewHandlerProvider(s)
	mbusHandler, err := mbusHandlerProvider.Get()
	if err != nil {
		return
	}

	a := agent.New(mbusHandler)
	err = a.Run()
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
