package app_test

import (
	. "bosh/davcli/app"
	davconf "bosh/davcli/config"
	"errors"
	. "github.com/onsi/ginkgo"
	"github.com/stretchr/testify/assert"
	"os"
	"path/filepath"
)

type FakeRunner struct {
	Config  davconf.Config
	RunArgs []string
	RunErr  error
}

func (r *FakeRunner) SetConfig(newConfig davconf.Config) {
	r.Config = newConfig
}

func (r *FakeRunner) Run(cmdArgs []string) (err error) {
	r.RunArgs = cmdArgs
	err = r.RunErr
	return
}

func pathToFixture(file string) string {
	pwd, _ := os.Getwd()
	fixturePath := filepath.Join(pwd, "../../../../fixtures", file)
	absPath, _ := filepath.Abs(fixturePath)
	return absPath
}
func init() {
	Describe("Testing with Ginkgo", func() {
		It("runs the put command", func() {
			runner := &FakeRunner{}

			app := New(runner)
			err := app.Run([]string{"dav-cli", "-c", pathToFixture("dav-cli-config.json"), "put", "localFile", "remoteFile"})
			assert.NoError(GinkgoT(), err)

			expectedConfig := davconf.Config{
				User:     "some user",
				Password: "some pwd",
				Endpoint: "http://example.com/some/endpoint",
			}

			assert.Equal(GinkgoT(), runner.Config, expectedConfig)
			assert.Equal(GinkgoT(), runner.RunArgs, []string{"put", "localFile", "remoteFile"})
		})
		It("returns error with no config argument", func() {

			runner := &FakeRunner{}

			app := New(runner)
			err := app.Run([]string{"put", "localFile", "remoteFile"})

			assert.Error(GinkgoT(), err)
			assert.Contains(GinkgoT(), err.Error(), "Config file arg `-c` is missing")
		})
		It("returns error from the cmd runner", func() {

			runner := &FakeRunner{
				RunErr: errors.New("Oops"),
			}

			app := New(runner)
			err := app.Run([]string{"dav-cli", "-c", pathToFixture("dav-cli-config.json"), "put", "localFile", "remoteFile"})

			assert.Error(GinkgoT(), err)
			assert.Equal(GinkgoT(), err, runner.RunErr)
		})
	})
}
