package testhelpers

import (
	"strings"
)

type FakeCmdRunner struct {
	CommandResults       map[string][]string
	RunCommands          [][]string
	RunCommandsWithInput [][]string
}

func (runner *FakeCmdRunner) RunCommand(cmdName string, args ...string) (stdout, stderr string, err error) {
	runCmd := append([]string{cmdName}, args...)
	runner.RunCommands = append(runner.RunCommands, runCmd)

	stdout, stderr = runner.getOutputsForCmd(runCmd)
	return
}

func (runner *FakeCmdRunner) RunCommandWithInput(input, cmdName string, args ...string) (stdout, stderr string, err error) {
	runCmd := append([]string{input, cmdName}, args...)
	runner.RunCommandsWithInput = append(runner.RunCommandsWithInput, runCmd)

	stdout, stderr = runner.getOutputsForCmd(runCmd)
	return
}

func (runner *FakeCmdRunner) getOutputsForCmd(runCmd []string) (stdout, stderr string) {
	result, found := runner.CommandResults[strings.Join(runCmd, " ")]
	if found {
		stdout = result[0]
		stderr = result[1]
	}
	return
}
