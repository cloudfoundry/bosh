package drain

import (
	boshsys "bosh/system"
	fakesys "bosh/system/fakes"
	"errors"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestRunArgs(t *testing.T) {
	drainScript, params, runner, _ := buildDrainScript(fakesys.FakeCmdResult{Stdout: "1"})

	_, err := drainScript.Run(params)
	assert.NoError(t, err)

	expectedCmd := boshsys.Command{
		Name: "/fake/script",
		Args: []string{"job_shutdown", "hash_unchanged", "foo", "bar"},
		Env: map[string]string{
			"PATH": "/usr/sbin:/usr/bin:/sbin:/bin",
		},
	}

	assert.Equal(t, 1, len(runner.RunComplexCommands))
	assert.Equal(t, expectedCmd, runner.RunComplexCommands[0])
}

func TestRunReturnsParsedSTDOUT(t *testing.T) {
	drainScript, params, _, _ := buildDrainScript(fakesys.FakeCmdResult{Stdout: "1"})

	value, err := drainScript.Run(params)
	assert.NoError(t, err)
	assert.Equal(t, value, 1)
}

func TestRunReturnsParsedSTDOUTAfterTrimming(t *testing.T) {
	drainScript, params, _, _ := buildDrainScript(fakesys.FakeCmdResult{Stdout: "-56\n"})

	value, err := drainScript.Run(params)
	assert.NoError(t, err)
	assert.Equal(t, value, -56)
}

func TestRunErrorsWithNonIntegerSTDOUT(t *testing.T) {
	drainScript, params, _, _ := buildDrainScript(fakesys.FakeCmdResult{Stdout: "hello!"})

	_, err := drainScript.Run(params)
	assert.Error(t, err)
}

func TestRunErrorsWhenRunningCommandErrors(t *testing.T) {
	drainScript, params, _, _ := buildDrainScript(fakesys.FakeCmdResult{Error: errors.New("woops")})

	_, err := drainScript.Run(params)
	assert.Error(t, err)
}

func TestExists(t *testing.T) {
	drainScript, _, _, fs := buildDrainScript(fakesys.FakeCmdResult{Stdout: "1"})

	assert.False(t, drainScript.Exists())

	fs.WriteToFile("/fake/script", "")

	assert.True(t, drainScript.Exists())
}

func buildDrainScript(commandResult fakesys.FakeCmdResult) (
	drainScript ConcreteDrainScript,
	params staticDrainParams,
	runner *fakesys.FakeCmdRunner,
	fs *fakesys.FakeFileSystem,
) {
	fs = fakesys.NewFakeFileSystem()
	runner = fakesys.NewFakeCmdRunner()
	drainScript = NewConcreteDrainScript(fs, runner, "/fake/script")
	params = staticDrainParams{
		jobChange:       "job_shutdown",
		hashChange:      "hash_unchanged",
		updatedPackages: []string{"foo", "bar"},
	}

	runner.AddCmdResult("/fake/script"+" job_shutdown hash_unchanged foo bar", commandResult)

	return
}
