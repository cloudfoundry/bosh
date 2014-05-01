package app

import (
	"flag"
	"io/ioutil"
)

type options struct {
	InfrastructureName string
	PlatformName       string
	BaseDirectory      string
	JobSupervisor      string
	ConfigPath         string
}

func ParseOptions(args []string) (options, error) {
	var opts options

	flagSet := flag.NewFlagSet("bosh-agent-args", flag.ContinueOnError)
	flagSet.SetOutput(ioutil.Discard)

	flagSet.StringVar(&opts.InfrastructureName, "I", "", "Set Infrastructure")
	flagSet.StringVar(&opts.PlatformName, "P", "", "Set Platform")

	flagSet.StringVar(&opts.ConfigPath, "C", "", "Config path")
	flagSet.StringVar(&opts.JobSupervisor, "M", "monit", "Set jobsupervisor")
	flagSet.StringVar(&opts.BaseDirectory, "b", "/var/vcap", "Set Base Directory")

	// The following two options are accepted but ignored for compatibility with the old agent
	var systemRoot string
	flagSet.StringVar(&systemRoot, "r", "/", "system root (ignored by go agent)")

	var noAlerts bool
	flagSet.BoolVar(&noAlerts, "no-alerts", false, "don't process alerts (ignored by go agent)")

	return opts, flagSet.Parse(args[1:])
}
