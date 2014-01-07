package cmd

import (
	davconf "bosh/davcli/config"
	"errors"
)

type Runner interface {
	SetConfig(newConfig davconf.Config)
	Run(cmdArgs []string) (err error)
}

func NewRunner(factory Factory) Runner {
	return runner{
		factory: factory,
	}
}

type runner struct {
	factory Factory
}

func (r runner) Run(cmdArgs []string) (err error) {
	if len(cmdArgs) == 0 {
		err = errors.New("Missing command name")
		return
	}

	cmd, err := r.factory.Create(cmdArgs[0])
	if err != nil {
		return
	}

	return cmd.Run(cmdArgs[1:])
}

func (r runner) SetConfig(newConfig davconf.Config) {
	r.factory.SetConfig(newConfig)
}
