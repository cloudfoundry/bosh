// +build !windows

package system

import (
	"strings"
	"syscall"
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
	p.logger.Debug(execProcessLogTag, "Running command '%s'", cmdString)

	if !p.keepAttached {
		p.cmd.SysProcAttr = &syscall.SysProcAttr{Setpgid: true}
	}

	err := p.cmd.Start()
	if err != nil {
		return bosherr.WrapErrorf(err, "Starting command '%s'", cmdString)
	}

	if !p.keepAttached {
		p.pgid = p.cmd.Process.Pid
	} else {
		p.pgid, err = syscall.Getpgid(p.pid)
		if err != nil {
			p.logger.Error(execProcessLogTag, "Failed to retrieve pgid for command '%s'", cmdString)
			p.pgid = -1
		}
	}

	return nil
}

// TerminateNicely can be called multiple times simultaneously from different goroutines
func (p *execProcess) TerminateNicely(killGracePeriod time.Duration) error {
	// Make sure process is being waited on for process state reaping to occur
	// as to avoid forcibly killing the process after killGracePeriod
	if p.waitCh == nil {
		panic("TerminateNicely() must be called after Wait()")
	}

	err := p.signalGroup(syscall.SIGTERM)
	if err != nil {
		return bosherr.WrapErrorf(err, "Sending SIGTERM to process group %d", p.pgid)
	}

	terminatedCh := make(chan struct{})
	stopCheckingTerminatedCh := make(chan struct{})

	go func() {
		for p.groupExists() {
			select {
			case <-time.After(500 * time.Millisecond):
				// nothing to do
			case <-stopCheckingTerminatedCh:
				return
			}
		}

		close(terminatedCh)
	}()

	select {
	case <-terminatedCh:
		// nothing to do

	case <-time.After(killGracePeriod):
		close(stopCheckingTerminatedCh)

		err = p.signalGroup(syscall.SIGKILL)
		if err != nil {
			return bosherr.WrapErrorf(err, "Sending SIGKILL to process group %d", p.pgid)
		}
	}

	// It takes some time for the process to disappear
	for i := 0; i < 20; i++ {
		if !p.groupExists() {
			return nil
		}
		time.Sleep(500 * time.Millisecond)
	}

	return bosherr.Errorf("Failed to kill process after grace timeout (PID %d)", p.pid)
}

// signalGroup does not return an error if the process group does not exist
func (p *execProcess) signalGroup(sig syscall.Signal) error {
	err := syscall.Kill(-p.pgid, sig)
	if p.isGroupDoesNotExistError(err) {
		return nil
	}
	return err
}

func (p *execProcess) groupExists() bool {
	err := syscall.Kill(-p.pgid, syscall.Signal(0))
	if p.isGroupDoesNotExistError(err) {
		return false
	}
	return true
}

func (p *execProcess) isGroupDoesNotExistError(err error) bool {
	if err == syscall.ESRCH {
		return true
	}
	if err == syscall.EPERM {
		// On BSD process is owned by no user while waiting to be reaped
		return true
	}
	return false
}
