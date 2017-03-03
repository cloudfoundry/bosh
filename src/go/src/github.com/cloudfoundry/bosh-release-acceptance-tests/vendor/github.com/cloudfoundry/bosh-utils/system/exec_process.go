package system

import (
	"bytes"
	"os/exec"
	"strings"
	"syscall"

	bosherr "github.com/cloudfoundry/bosh-utils/errors"
	boshlog "github.com/cloudfoundry/bosh-utils/logger"
)

const (
	execProcessLogTag = "Cmd Runner"
)

type execProcess struct {
	cmd          *exec.Cmd
	stdoutWriter *bytes.Buffer
	stderrWriter *bytes.Buffer
	keepAttached bool
	pid          int
	pgid         int
	logger       boshlog.Logger
	waitCh       chan Result
}

func NewExecProcess(cmd *exec.Cmd, keepAttached bool, logger boshlog.Logger) *execProcess {
	return &execProcess{
		cmd:          cmd,
		stdoutWriter: bytes.NewBufferString(""),
		stderrWriter: bytes.NewBufferString(""),
		keepAttached: keepAttached,
		logger:       logger,
	}
}

func (p *execProcess) Wait() <-chan Result {
	if p.waitCh != nil {
		panic("Wait() must be called only once")
	}

	// Use buffer=1 to allow goroutine below to finish
	p.waitCh = make(chan Result, 1)

	go func() {
		p.waitCh <- p.wait()
	}()

	return p.waitCh
}

func (p *execProcess) wait() Result {
	// err will be non-nil if command exits with non-0 status
	err := p.cmd.Wait()

	stdout := string(p.stdoutWriter.Bytes())
	p.logger.Debug(execProcessLogTag, "Stdout: %s", stdout)

	stderr := string(p.stderrWriter.Bytes())
	p.logger.Debug(execProcessLogTag, "Stderr: %s", stderr)

	exitStatus := -1
	waitStatus := p.cmd.ProcessState.Sys().(syscall.WaitStatus)

	if waitStatus.Exited() {
		exitStatus = waitStatus.ExitStatus()
	} else if waitStatus.Signaled() {
		exitStatus = 128 + int(waitStatus.Signal())
	}

	p.logger.Debug(execProcessLogTag, "Successful: %t (%d)", err == nil, exitStatus)

	if err != nil {
		cmdString := strings.Join(p.cmd.Args, " ")
		err = bosherr.WrapComplexError(err, NewExecError(cmdString, stdout, stderr))
	}

	return Result{
		Stdout:     stdout,
		Stderr:     stderr,
		ExitStatus: exitStatus,
		Error:      err,
	}
}
