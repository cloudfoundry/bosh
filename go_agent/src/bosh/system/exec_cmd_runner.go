package system

import (
	"bytes"
	"fmt"
	"os"
	"os/exec"
	"strings"
	"syscall"
	"time"

	bosherr "bosh/errors"
	boshlog "bosh/logger"
)

const (
	execProcessLogTag      = "Cmd Runner"
	execErrorMsgFmt        = "Running command: '%s', stdout: '%s', stderr: '%s'"
	execShortErrorMaxLines = 100
)

type ExecError struct {
	cmd    string
	stdout string
	stderr string
}

func NewExecError(cmd, stdout, stderr string) ExecError {
	return ExecError{
		cmd:    cmd,
		stdout: stdout,
		stderr: stderr,
	}
}

func (e ExecError) Error() string {
	return fmt.Sprintf(execErrorMsgFmt, e.cmd, e.stdout, e.stderr)
}

// ShortError returns an error message that has stdout/stderr truncated.
func (e ExecError) ShortError() string {
	outStr := e.truncateStr(e.stdout, execShortErrorMaxLines)
	errStr := e.truncateStr(e.stderr, execShortErrorMaxLines)
	return fmt.Sprintf(execErrorMsgFmt, e.cmd, outStr, errStr)
}

func (e ExecError) truncateStr(in string, maxLines int) string {
	outLines := strings.Split(in, "\n")
	if i := len(outLines); i > maxLines {
		outLines = outLines[i-maxLines:]
	}

	return strings.Join(outLines, "\n")
}

type execProcess struct {
	cmd          *exec.Cmd
	stdoutWriter *bytes.Buffer
	stderrWriter *bytes.Buffer
	pid          int
	logger       boshlog.Logger
	waitCh       chan Result
}

func newExecProcess(cmd *exec.Cmd, logger boshlog.Logger) *execProcess {
	return &execProcess{
		cmd:          cmd,
		stdoutWriter: bytes.NewBufferString(""),
		stderrWriter: bytes.NewBufferString(""),
		logger:       logger,
	}
}

func (p *execProcess) Start() error {
	p.cmd.Stdout = p.stdoutWriter
	p.cmd.Stderr = p.stderrWriter

	cmdString := strings.Join(p.cmd.Args, " ")
	p.logger.Debug(execProcessLogTag, "Running command: %s", cmdString)

	p.cmd.SysProcAttr = &syscall.SysProcAttr{Setpgid: true}

	err := p.cmd.Start()
	if err != nil {
		return bosherr.WrapError(err, "Starting command %s", cmdString)
	}

	p.pid = p.cmd.Process.Pid

	return nil
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

func (p execProcess) wait() Result {
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

// TerminateNicely can be called multiple times simultaneously from different goroutines
func (p *execProcess) TerminateNicely(killGracePeriod time.Duration) error {
	// Make sure process is being waited on for process state reaping to occur
	// as to avoid forcibly killing the process after killGracePeriod
	if p.waitCh == nil {
		panic("TerminateNicely() must be called after Wait()")
	}

	err := p.signalGroup(syscall.SIGTERM)
	if err != nil {
		return bosherr.WrapError(err, "Sending SIGTERM to process group %d", p.pid)
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
			return bosherr.WrapError(err, "Sending SIGKILL to process group %d", p.pid)
		}
	}

	// It takes some time for the process to disappear
	for i := 0; i < 20; i++ {
		if !p.groupExists() {
			return nil
		}
		time.Sleep(500 * time.Millisecond)
	}

	return bosherr.New("Failed to kill process after grace timeout (PID %d)", p.pid)
}

// signalGroup does not return an error if the process group does not exist
func (p *execProcess) signalGroup(sig syscall.Signal) error {
	err := syscall.Kill(-p.pid, sig)
	if p.isGroupDoesNotExistError(err) {
		return nil
	}
	return err
}

func (p *execProcess) groupExists() bool {
	err := syscall.Kill(-p.pid, syscall.Signal(0))
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

type execCmdRunner struct {
	logger boshlog.Logger
}

func NewExecCmdRunner(logger boshlog.Logger) CmdRunner {
	return execCmdRunner{logger}
}

func (r execCmdRunner) RunComplexCommand(cmd Command) (string, string, int, error) {
	process := newExecProcess(r.buildComplexCommand(cmd), r.logger)

	err := process.Start()
	if err != nil {
		return "", "", -1, err
	}

	result := <-process.Wait()

	return result.Stdout, result.Stderr, result.ExitStatus, result.Error
}

func (r execCmdRunner) RunComplexCommandAsync(cmd Command) (Process, error) {
	process := newExecProcess(r.buildComplexCommand(cmd), r.logger)

	err := process.Start()
	if err != nil {
		return nil, err
	}

	return process, nil
}

func (r execCmdRunner) RunCommand(cmdName string, args ...string) (string, string, int, error) {
	process := newExecProcess(exec.Command(cmdName, args...), r.logger)

	err := process.Start()
	if err != nil {
		return "", "", -1, err
	}

	result := <-process.Wait()

	return result.Stdout, result.Stderr, result.ExitStatus, result.Error
}

func (r execCmdRunner) RunCommandWithInput(input, cmdName string, args ...string) (string, string, int, error) {
	execCmd := exec.Command(cmdName, args...)
	execCmd.Stdin = strings.NewReader(input)

	process := newExecProcess(execCmd, r.logger)

	err := process.Start()
	if err != nil {
		return "", "", -1, err
	}

	result := <-process.Wait()

	return result.Stdout, result.Stderr, result.ExitStatus, result.Error
}

func (r execCmdRunner) CommandExists(cmdName string) bool {
	_, err := exec.LookPath(cmdName)
	return err == nil
}

func (r execCmdRunner) buildComplexCommand(cmd Command) *exec.Cmd {
	execCmd := exec.Command(cmd.Name, cmd.Args...)

	execCmd.Dir = cmd.WorkingDir

	env := os.Environ()
	for name, value := range cmd.Env {
		env = append(env, fmt.Sprintf("%s=%s", name, value))
	}
	execCmd.Env = env

	return execCmd
}
