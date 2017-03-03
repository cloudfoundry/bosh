package system

import (
	"strings"
	"time"

	bosherr "github.com/cloudfoundry/bosh-utils/errors"
)

func (p *execProcess) Start() error {
	if p.cmd.Stdout == nil {
		p.cmd.Stdout = p.stdoutWriter
	}
	if p.cmd.Stderr == nil {
		p.cmd.Stderr = p.stderrWriter
	}
	cmdString := strings.Join(p.cmd.Args, " ")
	p.logger.Debug(execProcessLogTag, "Running command: %s", cmdString)

	err := p.cmd.Start()
	if err != nil {
		return bosherr.WrapErrorf(err, "Starting command %s", cmdString)
	}

	p.pid = p.cmd.Process.Pid
	return nil
}

func (p *execProcess) TerminateNicely(killGracePeriod time.Duration) error {
	p.logger.Debug(execProcessLogTag, "Terminating process with PID '%d'", p.pid)

	// Make sure process is being waited on for process state reaping to occur
	// as to avoid forcibly killing the process
	if p.waitCh == nil {
		panic("TerminateNicely() must be called after Wait()")
	}

	// If the process exits before Wait() can be called the
	// ProcessState may not be set and Kill() will fail with
	// an: "TerminateProcess: Access is denied" error.
	//
	// See: https://github.com/golang/go/issues/5615

	if p.cmd.ProcessState != nil && p.cmd.ProcessState.Exited() {
		p.logger.Debug(execProcessLogTag, "Skipping process termination: process exited")
		return nil
	}

	err := p.cmd.Process.Kill()
	if err != nil {
		return bosherr.WrapErrorf(err, "Terminating process: %#v", err)
	}

	return nil
}
