package system

import (
	boshlog "bosh/logger"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestRunCommand(t *testing.T) {
	runner := createRunner()

	stdout, stderr, err := runner.RunCommand("echo", "Hello World!")
	assert.NoError(t, err)
	assert.Empty(t, stderr)
	assert.Equal(t, stdout, "Hello World!\n")
}

func TestRunCommandWithErrorOutput(t *testing.T) {
	runner := createRunner()

	stdout, stderr, err := runner.RunCommand("sh", "-c", "echo error-output >&2")
	assert.NoError(t, err)
	assert.Contains(t, stderr, "error-output")
	assert.Empty(t, stdout)
}

func TestRunCommandWithError(t *testing.T) {
	runner := createRunner()

	stdout, stderr, err := runner.RunCommand("false")
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "status 1")
	assert.Empty(t, stderr)
	assert.Empty(t, stdout)
}

func TestRunCommandWithCmdNotFound(t *testing.T) {
	runner := createRunner()

	stdout, stderr, err := runner.RunCommand("something that does not exist")
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "not found")
	assert.Empty(t, stderr)
	assert.Empty(t, stdout)
}

func TestRunCommandWithInput(t *testing.T) {
	runner := createRunner()

	stdout, stderr, err := runner.RunCommandWithInput("foo\nbar\nbaz", "grep", "ba")

	assert.NoError(t, err)
	assert.Equal(t, "bar\nbaz\n", stdout)
	assert.Empty(t, stderr)
}

func createRunner() (r CmdRunner) {
	r = NewExecCmdRunner(boshlog.NewLogger(boshlog.LEVEL_NONE))
	return
}
