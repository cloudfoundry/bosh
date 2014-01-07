package system

import (
	boshlog "bosh/logger"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestRunComplexCommandWithWorkingDirectory(t *testing.T) {
	cmd := Command{
		Name:       "ls",
		Args:       []string{"-l"},
		WorkingDir: "../../..",
	}
	runner := createRunner()
	stdout, stderr, err := runner.RunComplexCommand(cmd)
	assert.NoError(t, err)
	assert.Empty(t, stderr)
	assert.Contains(t, stdout, "README.md")
	assert.Contains(t, stdout, "total")
}

func TestRunComplexCommandWithEnv(t *testing.T) {
	cmd := Command{
		Name: "env",
		Env: map[string]string{
			"FOO": "BAR",
		},
	}
	runner := createRunner()
	stdout, stderr, err := runner.RunComplexCommand(cmd)
	assert.NoError(t, err)
	assert.Empty(t, stderr)
	assert.Contains(t, stdout, "FOO=BAR")
	assert.Contains(t, stdout, "PATH=")
}

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
	assert.Equal(t, err.Error(), "Running command: 'false', stdout: '', stderr: '': exit status 1")
	assert.Empty(t, stderr)
	assert.Empty(t, stdout)
}

func TestRunCommandWithErrorWithArgs(t *testing.T) {
	runner := createRunner()

	stdout, stderr, err := runner.RunCommand("false", "second arg")
	assert.Error(t, err)
	assert.Equal(t, err.Error(), "Running command: 'false second arg', stdout: '', stderr: '': exit status 1")
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

func TestCommandExists(t *testing.T) {
	runner := createRunner()

	assert.True(t, runner.CommandExists("env"))
	assert.False(t, runner.CommandExists("absolutely-does-not-exist-ever-please-unicorns"))
}

func createRunner() (r CmdRunner) {
	r = NewExecCmdRunner(boshlog.NewLogger(boshlog.LEVEL_NONE))
	return
}
