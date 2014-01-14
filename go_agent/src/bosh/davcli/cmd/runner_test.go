package cmd

import (
	davconf "bosh/davcli/config"
	"errors"
	"github.com/stretchr/testify/assert"
	"testing"
)

type FakeFactory struct {
	CreateName string
	CreateCmd  *FakeCmd
	CreateErr  error

	Config davconf.Config
}

func (f *FakeFactory) Create(name string) (cmd Cmd, err error) {
	f.CreateName = name
	cmd = f.CreateCmd
	err = f.CreateErr
	return
}

func (f *FakeFactory) SetConfig(config davconf.Config) {
	f.Config = config
}

type FakeCmd struct {
	RunArgs []string
	RunErr  error
}

func (cmd *FakeCmd) Run(args []string) (err error) {
	cmd.RunArgs = args
	err = cmd.RunErr
	return
}

func TestRunCanRunACommandAndReturnItsError(t *testing.T) {
	factory := &FakeFactory{
		CreateCmd: &FakeCmd{
			RunErr: errors.New("Error running cmd"),
		},
	}
	cmdRunner := NewRunner(factory)

	err := cmdRunner.Run([]string{"put", "foo", "bar"})
	assert.Error(t, err)
	assert.Equal(t, err.Error(), "Error running cmd")

	assert.Equal(t, factory.CreateName, "put")
	assert.Equal(t, factory.CreateCmd.RunArgs, []string{"foo", "bar"})
}

func TestRunExpectsAtLeastOneArgument(t *testing.T) {
	factory := &FakeFactory{
		CreateCmd: &FakeCmd{},
	}
	cmdRunner := NewRunner(factory)

	err := cmdRunner.Run([]string{})
	assert.Error(t, err)
	assert.Equal(t, err.Error(), "Missing command name")
}

func TestAcceptsExactlyOneArgument(t *testing.T) {
	factory := &FakeFactory{
		CreateCmd: &FakeCmd{},
	}
	cmdRunner := NewRunner(factory)

	err := cmdRunner.Run([]string{"put"})
	assert.NoError(t, err)

	assert.Equal(t, factory.CreateName, "put")
	assert.Equal(t, factory.CreateCmd.RunArgs, []string{})
}

func TestSetConfig(t *testing.T) {
	factory := &FakeFactory{}
	cmdRunner := NewRunner(factory)
	conf := davconf.Config{User: "foo"}

	cmdRunner.SetConfig(conf)

	assert.Equal(t, factory.Config, conf)
}
