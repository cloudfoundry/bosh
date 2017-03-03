package fakes

import (
	"fmt"
	"io"
	"strings"
	"sync"
	"time"

	boshsys "github.com/cloudfoundry/bosh-utils/system"
)

type FakeCmdRunner struct {
	commandResults     map[string][]FakeCmdResult
	commandResultsLock sync.Mutex

	processes     map[string][]*FakeProcess
	processesLock sync.Mutex

	RunComplexCommands   []boshsys.Command
	RunCommands          [][]string
	RunCommandsWithInput [][]string
	runCommandCallbacks  map[string]FakeCmdCallback

	CommandExistsValue bool
	AvailableCommands  map[string]bool
}

type FakeCmdCallback func()

type FakeCmdResult struct {
	Stdout     string
	Stderr     string
	ExitStatus int
	Error      error

	Sticky bool // Set to true if this result should ALWAYS be returned for the given command
}

type FakeProcess struct {
	StartErr error

	WaitCh chan boshsys.Result

	Waited     bool
	WaitResult boshsys.Result

	TerminatedNicely               bool
	TerminatedNicelyCallBack       func(*FakeProcess)
	TerminateNicelyKillGracePeriod time.Duration
	TerminateNicelyErr             error

	Stdout io.Writer
	Stderr io.Writer
}

func (p *FakeProcess) Wait() <-chan boshsys.Result {
	if p.Waited {
		panic("Cannot Wait() on process multiple times")
	}

	p.Waited = true
	p.WaitCh = make(chan boshsys.Result, 1)

	if p.TerminatedNicelyCallBack == nil {
		p.WaitCh <- p.WaitResult
	}
	return p.WaitCh
}

func (p *FakeProcess) TerminateNicely(killGracePeriod time.Duration) error {
	p.TerminateNicelyKillGracePeriod = killGracePeriod
	p.TerminatedNicely = true
	if p.TerminatedNicelyCallBack != nil {
		p.TerminatedNicelyCallBack(p)
	}
	return p.TerminateNicelyErr
}

func NewFakeCmdRunner() *FakeCmdRunner {
	return &FakeCmdRunner{
		AvailableCommands:   map[string]bool{},
		commandResults:      map[string][]FakeCmdResult{},
		runCommandCallbacks: map[string]FakeCmdCallback{},
		processes:           map[string][]*FakeProcess{},
	}
}

func (r *FakeCmdRunner) RunComplexCommand(cmd boshsys.Command) (string, string, int, error) {
	r.commandResultsLock.Lock()
	defer r.commandResultsLock.Unlock()

	r.RunComplexCommands = append(r.RunComplexCommands, cmd)

	runCmd := append([]string{cmd.Name}, cmd.Args...)

	r.runCallbackForCmd(runCmd)

	stdout, stderr, exitstatus, err := r.getOutputsForCmd(runCmd)

	if cmd.Stdout != nil {
		cmd.Stdout.Write([]byte(stdout))
	}

	if cmd.Stderr != nil {
		cmd.Stderr.Write([]byte(stderr))
	}

	return stdout, stderr, exitstatus, err
}

func (r *FakeCmdRunner) RunComplexCommandAsync(cmd boshsys.Command) (boshsys.Process, error) {
	r.processesLock.Lock()
	defer r.processesLock.Unlock()

	r.RunComplexCommands = append(r.RunComplexCommands, cmd)

	runCmd := append([]string{cmd.Name}, cmd.Args...)

	r.runCallbackForCmd(runCmd)

	fullCmd := strings.Join(runCmd, " ")

	results, found := r.processes[fullCmd]
	if !found {
		panic(fmt.Sprintf("Failed to find process for %s", fullCmd))
	}

	results[0].Stdout = cmd.Stdout
	results[0].Stderr = cmd.Stderr

	for _, proc := range results {
		if !proc.Waited {
			return proc, proc.StartErr
		}
	}

	panic(fmt.Sprintf("Failed to find available process for %s", fullCmd))
}

func (r *FakeCmdRunner) RunCommand(cmdName string, args ...string) (string, string, int, error) {
	r.commandResultsLock.Lock()
	defer r.commandResultsLock.Unlock()

	runCmd := append([]string{cmdName}, args...)
	r.RunCommands = append(r.RunCommands, runCmd)

	r.runCallbackForCmd(runCmd)

	return r.getOutputsForCmd(runCmd)
}

func (r *FakeCmdRunner) RunCommandWithInput(input, cmdName string, args ...string) (string, string, int, error) {
	r.commandResultsLock.Lock()
	defer r.commandResultsLock.Unlock()

	runCmd := append([]string{input, cmdName}, args...)
	r.RunCommandsWithInput = append(r.RunCommandsWithInput, runCmd)

	r.runCallbackForCmd(runCmd)

	return r.getOutputsForCmd(runCmd)
}

func (r *FakeCmdRunner) CommandExists(cmdName string) bool {
	return r.CommandExistsValue || r.AvailableCommands[cmdName]
}

func (r *FakeCmdRunner) AddCmdResult(fullCmd string, result FakeCmdResult) {
	r.commandResultsLock.Lock()
	defer r.commandResultsLock.Unlock()

	results := r.commandResults[fullCmd]
	r.commandResults[fullCmd] = append(results, result)
}

func (r *FakeCmdRunner) AddProcess(fullCmd string, process *FakeProcess) {
	r.processesLock.Lock()
	defer r.processesLock.Unlock()

	processes := r.processes[fullCmd]
	r.processes[fullCmd] = append(processes, process)
}

func (r *FakeCmdRunner) SetCmdCallback(fullCmd string, callback FakeCmdCallback) {
	r.runCommandCallbacks[fullCmd] = callback
}

func (r *FakeCmdRunner) getOutputsForCmd(runCmd []string) (string, string, int, error) {
	fullCmd := strings.Join(runCmd, " ")
	results, found := r.commandResults[fullCmd]
	if found {
		result := results[0]
		newResults := []FakeCmdResult{}
		if len(results) > 1 {
			newResults = results[1:]
		}

		if !result.Sticky {
			r.commandResults[fullCmd] = newResults
		}

		return result.Stdout, result.Stderr, result.ExitStatus, result.Error
	}

	return "", "", -1, nil
}

func (r *FakeCmdRunner) runCallbackForCmd(runCmd []string) {
	fullCmd := strings.Join(runCmd, " ")
	runCmdCallback, found := r.runCommandCallbacks[fullCmd]
	if found {
		runCmdCallback()
	}
}
