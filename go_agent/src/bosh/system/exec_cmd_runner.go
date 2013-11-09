package system

import (
	bosherr "bosh/errors"
	"bytes"
	"fmt"
	"os/exec"
	"strings"
)

type ExecCmdRunner struct {
}

func (run ExecCmdRunner) RunCommand(cmdName string, args ...string) (stdout, stderr string, err error) {
	return runCmd(cmdName, args, nil)
}

func (run ExecCmdRunner) RunCommandWithInput(input, cmdName string, args ...string) (stdout, stderr string, err error) {
	return runCmd(cmdName, args, func(cmd *exec.Cmd) {
		cmd.Stdin = strings.NewReader(input)
	})
}

func runCmd(cmdName string, args []string, cmdHook func(*exec.Cmd)) (stdout, stderr string, err error) {
	cmd := exec.Command(cmdName, args...)
	cmdString := strings.Join(append([]string{cmdName}, args...), " ")

	stdoutWriter := bytes.NewBufferString("")
	stderrWriter := bytes.NewBufferString("")
	cmd.Stdout = stdoutWriter
	cmd.Stderr = stderrWriter

	if cmdHook != nil {
		cmdHook(cmd)
	}

	err = cmd.Start()
	if err != nil {
		err = bosherr.WrapError(err, fmt.Sprintf("Error starting command %s", cmdString))
		return
	}

	err = cmd.Wait()
	stdout = string(stdoutWriter.Bytes())
	stderr = string(stderrWriter.Bytes())
	if err != nil {
		err = bosherr.WrapError(err, fmt.Sprintf("Error running command: '%s', stdout: '%s', stderr: '%s'",
			cmdString, stdout, stderr))
	}
	return
}
