package system

import (
	"os"
	"os/exec"
	"runtime"
	"strings"

	boshlog "github.com/cloudfoundry/bosh-utils/logger"
)

type execCmdRunner struct {
	logger boshlog.Logger
}

func NewExecCmdRunner(logger boshlog.Logger) CmdRunner {
	return execCmdRunner{logger}
}

func (r execCmdRunner) RunComplexCommand(cmd Command) (string, string, int, error) {
	process := NewExecProcess(r.buildComplexCommand(cmd), cmd.KeepAttached, cmd.Quiet, r.logger)

	err := process.Start()
	if err != nil {
		return "", "", -1, err
	}

	result := <-process.Wait()

	return result.Stdout, result.Stderr, result.ExitStatus, result.Error
}

func (r execCmdRunner) RunComplexCommandAsync(cmd Command) (Process, error) {
	process := NewExecProcess(r.buildComplexCommand(cmd), cmd.KeepAttached, cmd.Quiet, r.logger)

	err := process.Start()
	if err != nil {
		return nil, err
	}

	return process, nil
}

func (r execCmdRunner) RunCommand(cmdName string, args ...string) (string, string, int, error) {
	return r.RunComplexCommand(Command{Name: cmdName, Args: args})
}

func (r execCmdRunner) RunCommandQuietly(cmdName string, args ...string) (string, string, int, error) {
	return r.RunComplexCommand(Command{Name: cmdName, Args: args, Quiet: true})
}

func (r execCmdRunner) RunCommandWithInput(input, cmdName string, args ...string) (string, string, int, error) {
	cmd := Command{
		Name:  cmdName,
		Args:  args,
		Stdin: strings.NewReader(input),
	}
	return r.RunComplexCommand(cmd)
}

func (r execCmdRunner) CommandExists(cmdName string) bool {
	_, err := exec.LookPath(cmdName)
	return err == nil
}

func (r execCmdRunner) buildComplexCommand(cmd Command) *exec.Cmd {
	execCmd := newExecCmd(cmd.Name, cmd.Args...)

	if cmd.Stdin != nil {
		execCmd.Stdin = cmd.Stdin
	}

	if cmd.Stdout != nil {
		execCmd.Stdout = cmd.Stdout
	}

	if cmd.Stderr != nil {
		execCmd.Stderr = cmd.Stderr
	}

	execCmd.Dir = cmd.WorkingDir

	var env []string
	if !cmd.UseIsolatedEnv {
		env = os.Environ()
	}
	if cmd.UseIsolatedEnv && runtime.GOOS == "windows" {
		panic("UseIsolatedEnv is not supported on Windows")
	}

	execCmd.Env = mergeEnv(env, cmd.Env)

	return execCmd
}
