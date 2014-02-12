package cmd_test

import (
	. "bosh/davcli/cmd"
	davconf "bosh/davcli/config"
	"errors"
	. "github.com/onsi/ginkgo"
	"github.com/stretchr/testify/assert"
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
func init() {
	Describe("Testing with Ginkgo", func() {
		It("run can run a command and return its error", func() {

			factory := &FakeFactory{
				CreateCmd: &FakeCmd{
					RunErr: errors.New("Error running cmd"),
				},
			}
			cmdRunner := NewRunner(factory)

			err := cmdRunner.Run([]string{"put", "foo", "bar"})
			assert.Error(GinkgoT(), err)
			assert.Equal(GinkgoT(), err.Error(), "Error running cmd")

			assert.Equal(GinkgoT(), factory.CreateName, "put")
			assert.Equal(GinkgoT(), factory.CreateCmd.RunArgs, []string{"foo", "bar"})
		})
		It("run expects at least one argument", func() {

			factory := &FakeFactory{
				CreateCmd: &FakeCmd{},
			}
			cmdRunner := NewRunner(factory)

			err := cmdRunner.Run([]string{})
			assert.Error(GinkgoT(), err)
			assert.Equal(GinkgoT(), err.Error(), "Missing command name")
		})
		It("accepts exactly one argument", func() {

			factory := &FakeFactory{
				CreateCmd: &FakeCmd{},
			}
			cmdRunner := NewRunner(factory)

			err := cmdRunner.Run([]string{"put"})
			assert.NoError(GinkgoT(), err)

			assert.Equal(GinkgoT(), factory.CreateName, "put")
			assert.Equal(GinkgoT(), factory.CreateCmd.RunArgs, []string{})
		})
		It("set config", func() {

			factory := &FakeFactory{}
			cmdRunner := NewRunner(factory)
			conf := davconf.Config{User: "foo"}

			cmdRunner.SetConfig(conf)

			assert.Equal(GinkgoT(), factory.Config, conf)
		})
	})
}
