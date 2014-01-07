package system

import (
	bosherr "bosh/errors"
	boshlog "bosh/logger"
	"bytes"
	"fmt"
	"os"
	"os/exec"
	"strings"
)

type execCmdRunner struct {
	logger boshlog.Logger
}

func NewExecCmdRunner(logger boshlog.Logger) (cmRunner CmdRunner) {
	return execCmdRunner{logger}
}

func (run execCmdRunner) RunComplexCommand(cmd Command) (stdout, stderr string, err error) {
	execCmd := exec.Command(cmd.Name, cmd.Args...)
	execCmd.Dir = cmd.WorkingDir
	env := os.Environ()
	for name, value := range cmd.Env {
		env = append(env, fmt.Sprintf("%s=%s", name, value))
	}
	execCmd.Env = env

	return run.runCmd(execCmd)
}

func (run execCmdRunner) RunCommand(cmdName string, args ...string) (stdout, stderr string, err error) {
	cmd := exec.Command(cmdName, args...)
	return run.runCmd(cmd)
}

func (run execCmdRunner) RunCommandWithInput(input, cmdName string, args ...string) (stdout, stderr string, err error) {
	cmd := exec.Command(cmdName, args...)
	cmd.Stdin = strings.NewReader(input)
	return run.runCmd(cmd)
}

func (run execCmdRunner) CommandExists(cmdName string) (exists bool) {
	_, err := exec.LookPath(cmdName)
	if err != nil {
		return false
	}

	return true
}

func (run execCmdRunner) runCmd(cmd *exec.Cmd) (stdout, stderr string, err error) {
	cmdString := strings.Join(cmd.Args, " ")

	run.logger.Debug("Cmd Runner", "Running command: %s", cmdString)

	stdoutWriter := bytes.NewBufferString("")
	stderrWriter := bytes.NewBufferString("")
	cmd.Stdout = stdoutWriter
	cmd.Stderr = stderrWriter

	err = cmd.Start()
	if err != nil {
		err = bosherr.WrapError(err, "Starting command %s", cmdString)
		return
	}

	err = cmd.Wait()
	stdout = string(stdoutWriter.Bytes())
	stderr = string(stderrWriter.Bytes())

	run.logger.Debug("Cmd Runner", "Stdout: %s", stdout)
	run.logger.Debug("Cmd Runner", "Stderr: %s", stderr)
	run.logger.Debug("Cmd Runner", "Successful: %t", err == nil)

	if err != nil {
		err = bosherr.WrapError(err, "Running command: '%s', stdout: '%s', stderr: '%s'", cmdString, stdout, stderr)
	}
	return
}
