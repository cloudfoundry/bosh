package fakes

import (
	"strings"

	boshsys "bosh/system"
)

type FakeCmdRunner struct {
	CommandResults map[string][]FakeCmdResult

	RunComplexCommands   []boshsys.Command
	RunCommands          [][]string
	RunCommandsWithInput [][]string

	CommandExistsValue bool
	AvailableCommands  map[string]bool
}

type FakeCmdResult struct {
	Stdout     string
	Stderr     string
	ExitStatus int
	Error      error
	Sticky     bool //Set to true if this result should ALWAYS be returned for the given command
}

func NewFakeCmdRunner() *FakeCmdRunner {
	return &FakeCmdRunner{
		AvailableCommands: map[string]bool{},
	}
}

func (runner *FakeCmdRunner) RunComplexCommand(cmd boshsys.Command) (string, string, int, error) {
	runner.RunComplexCommands = append(runner.RunComplexCommands, cmd)
	runCmd := append([]string{cmd.Name}, cmd.Args...)
	return runner.getOutputsForCmd(runCmd)
}

func (runner *FakeCmdRunner) RunCommand(cmdName string, args ...string) (string, string, int, error) {
	runCmd := append([]string{cmdName}, args...)
	runner.RunCommands = append(runner.RunCommands, runCmd)
	return runner.getOutputsForCmd(runCmd)
}

func (runner *FakeCmdRunner) RunCommandWithInput(input, cmdName string, args ...string) (string, string, int, error) {
	runCmd := append([]string{input, cmdName}, args...)
	runner.RunCommandsWithInput = append(runner.RunCommandsWithInput, runCmd)
	return runner.getOutputsForCmd(runCmd)
}

func (runner *FakeCmdRunner) CommandExists(cmdName string) bool {
	if runner.CommandExistsValue {
		return true
	}

	if runner.AvailableCommands[cmdName] {
		return true
	}

	return false
}

func (runner *FakeCmdRunner) AddCmdResult(fullCmd string, result FakeCmdResult) {
	if runner.CommandResults == nil {
		runner.CommandResults = make(map[string][]FakeCmdResult)
	}
	results := runner.CommandResults[fullCmd]
	runner.CommandResults[fullCmd] = append(results, result)
}

func (runner *FakeCmdRunner) getOutputsForCmd(runCmd []string) (string, string, int, error) {
	fullCmd := strings.Join(runCmd, " ")

	results, found := runner.CommandResults[fullCmd]
	if found {
		result := results[0]
		newResults := []FakeCmdResult{}
		if len(results) > 1 {
			newResults = results[1:]
		}

		if !result.Sticky {
			runner.CommandResults[fullCmd] = newResults
		}
		return result.Stdout, result.Stderr, result.ExitStatus, result.Error
	}
	return "", "", -1, nil
}
