package cmd_test

import (
	"errors"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	. "bosh/davcli/cmd"
	davconf "bosh/davcli/config"
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
					RunErr: errors.New("fake-run-error"),
				},
			}
			cmdRunner := NewRunner(factory)

			err := cmdRunner.Run([]string{"put", "foo", "bar"})
			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(Equal("fake-run-error"))

			Expect(factory.CreateName).To(Equal("put"))
			Expect(factory.CreateCmd.RunArgs).To(Equal([]string{"foo", "bar"}))
		})

		It("run expects at least one argument", func() {
			factory := &FakeFactory{
				CreateCmd: &FakeCmd{},
			}
			cmdRunner := NewRunner(factory)

			err := cmdRunner.Run([]string{})
			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(Equal("Missing command name"))
		})

		It("accepts exactly one argument", func() {
			factory := &FakeFactory{
				CreateCmd: &FakeCmd{},
			}
			cmdRunner := NewRunner(factory)

			err := cmdRunner.Run([]string{"put"})
			Expect(err).ToNot(HaveOccurred())

			Expect(factory.CreateName).To(Equal("put"))
			Expect(factory.CreateCmd.RunArgs).To(Equal([]string{}))
		})

		It("set config", func() {
			factory := &FakeFactory{}
			cmdRunner := NewRunner(factory)
			conf := davconf.Config{User: "foo"}

			cmdRunner.SetConfig(conf)

			Expect(factory.Config).To(Equal(conf))
		})
	})
}
