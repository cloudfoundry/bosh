package fakes

import (
	"errors"
	"strings"
)

type FakeCmdRunner struct {
	CommandResults       map[string][][]string
	RunCommands          [][]string
	RunCommandsWithInput [][]string
}

func (runner *FakeCmdRunner) RunCommand(cmdName string, args ...string) (stdout, stderr string, err error) {
	runCmd := append([]string{cmdName}, args...)
	runner.RunCommands = append(runner.RunCommands, runCmd)

	stdout, stderr, err = runner.getOutputsForCmd(runCmd)
	return
}

func (runner *FakeCmdRunner) RunCommandWithInput(input, cmdName string, args ...string) (stdout, stderr string, err error) {
	runCmd := append([]string{input, cmdName}, args...)
	runner.RunCommandsWithInput = append(runner.RunCommandsWithInput, runCmd)

	stdout, stderr, err = runner.getOutputsForCmd(runCmd)
	return
}

func (runner *FakeCmdRunner) AddCmdResult(fullCmd string, result []string) {
	if runner.CommandResults == nil {
		runner.CommandResults = make(map[string][][]string)
	}

	results := runner.CommandResults[fullCmd]
	runner.CommandResults[fullCmd] = append(results, result)
}

func (runner *FakeCmdRunner) getOutputsForCmd(runCmd []string) (stdout, stderr string, err error) {
	fullCmd := strings.Join(runCmd, " ")
	results, found := runner.CommandResults[fullCmd]

	if found {
		result := results[0]
		newResults := [][]string{}
		if len(results) > 1 {
			newResults = results[1:]
		}
		runner.CommandResults[fullCmd] = newResults

		stdout = result[0]
		stderr = result[1]
		if stderr != "" {
			err = errors.New(stderr)
		}
	}
	return
}
