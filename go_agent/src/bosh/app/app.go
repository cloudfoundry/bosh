package app

import (
	"bosh/bootstrap"
	"bosh/filesystem"
	"bosh/infrastructure"
	"flag"
	"io/ioutil"
)

type App struct {
}

type options struct {
	InfrastructureName string
}

func New() (app App) {
	return
}

func (app App) Run(args []string) (err error) {
	fs := filesystem.OsFileSystem{}

	opts, err := parseOptions(args)
	if err != nil {
		return
	}

	infProvider := infrastructure.NewProvider()
	infrastructure, err := infProvider.Get(opts.InfrastructureName)
	if err != nil {
		return
	}

	b := bootstrap.New(fs, infrastructure)
	err = b.Run()
	return
}

func parseOptions(args []string) (opts options, err error) {
	flagSet := flag.NewFlagSet("bosh-agent-args", flag.ContinueOnError)
	flagSet.SetOutput(ioutil.Discard)
	flagSet.StringVar(&opts.InfrastructureName, "I", "", "Set Infrastructure")

	err = flagSet.Parse(args[1:])
	return
}
