package system

import (
	"bytes"
	"os/exec"
)

type ExecCmdRunner struct {
}

func (run ExecCmdRunner) RunCommand(cmdName string, args ...string) (stdout, stderr string, err error) {
	cmd := exec.Command(cmdName, args...)

	stdoutWriter := bytes.NewBufferString("")
	stderrWriter := bytes.NewBufferString("")
	cmd.Stdout = stdoutWriter
	cmd.Stderr = stderrWriter

	err = cmd.Start()
	if err != nil {
		return
	}

	err = cmd.Wait()
	stdout = string(stdoutWriter.Bytes())
	stderr = string(stderrWriter.Bytes())
	return
}
