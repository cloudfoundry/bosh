package cmd

import (
	davclient "bosh/davcli/client"
	davconf "bosh/davcli/config"
	"errors"
	"fmt"
)

type Factory interface {
	Create(name string) (cmd Cmd, err error)
	SetConfig(config davconf.Config)
}

func NewFactory() (f Factory) {
	return &factory{cmds: make(map[string]Cmd)}
}

type factory struct {
	config davconf.Config
	cmds   map[string]Cmd
}

func (f *factory) Create(name string) (cmd Cmd, err error) {
	cmd, found := f.cmds[name]
	if !found {
		err = errors.New(fmt.Sprintf("Could not find command with name %s", name))
	}
	return
}

func (f *factory) SetConfig(config davconf.Config) {
	client := davclient.NewClient(config)

	f.cmds = map[string]Cmd{
		"put": newPutCmd(client),
		"get": newGetCmd(client),
	}
}
