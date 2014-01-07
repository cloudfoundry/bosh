package app

import (
	davconf "bosh/davcli/config"
	"errors"
	"github.com/stretchr/testify/assert"
	"os"
	"path/filepath"
	"testing"
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

func TestRunsThePutCommand(t *testing.T) {
	runner := &FakeRunner{}

	app := New(runner)
	err := app.Run([]string{"-c", pathToFixture("dav-cli-config.json"), "put", "localFile", "remoteFile"})
	assert.NoError(t, err)

	expectedConfig := davconf.Config{
		Username: "some user",
		Password: "some pwd",
		Endpoint: "http://example.com/some/endpoint",
	}

	assert.Equal(t, runner.Config, expectedConfig)
	assert.Equal(t, runner.RunArgs, []string{"put", "localFile", "remoteFile"})
}

func TestReturnsErrorWithNoConfigArgument(t *testing.T) {
	runner := &FakeRunner{}

	app := New(runner)
	err := app.Run([]string{"put", "localFile", "remoteFile"})

	assert.Error(t, err)
	assert.Contains(t, err.Error(), "Config file arg `-c` is missing")
}

func TestReturnsErrorFromTheCmdRunner(t *testing.T) {
	runner := &FakeRunner{
		RunErr: errors.New("Oops"),
	}

	app := New(runner)
	err := app.Run([]string{"-c", pathToFixture("dav-cli-config.json"), "put", "localFile", "remoteFile"})

	assert.Error(t, err)
	assert.Equal(t, err, runner.RunErr)
}

func pathToFixture(file string) string {
	pwd, _ := os.Getwd()
	fixturePath := filepath.Join(pwd, "../../../../fixtures", file)
	absPath, _ := filepath.Abs(fixturePath)
	return absPath
}
