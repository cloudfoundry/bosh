package action

import (
	"errors"
	"path/filepath"
	"time"

	boshas "bosh/agent/applier/applyspec"
	bosherr "bosh/errors"
	boshlog "bosh/logger"
	boshsys "bosh/system"
)

const runErrandActionLogTag = "runErrandAction"

type RunErrandAction struct {
	specService boshas.V1Service
	jobsDir     string
	cmdRunner   boshsys.CmdRunner
	logger      boshlog.Logger

	cancelCh chan struct{}
}

func NewRunErrand(
	specService boshas.V1Service,
	jobsDir string,
	cmdRunner boshsys.CmdRunner,
	logger boshlog.Logger,
) RunErrandAction {
	return RunErrandAction{
		specService: specService,
		jobsDir:     jobsDir,
		cmdRunner:   cmdRunner,
		logger:      logger,

		// Initialize channel in a constructor to avoid race
		// between initializing in Run()/Cancel()
		cancelCh: make(chan struct{}, 1),
	}
}

func (a RunErrandAction) IsAsynchronous() bool {
	return true
}

func (a RunErrandAction) IsPersistent() bool {
	return false
}

type ErrandResult struct {
	Stdout     string `json:"stdout"`
	Stderr     string `json:"stderr"`
	ExitStatus int    `json:"exit_code"`
}

func (a RunErrandAction) Run() (ErrandResult, error) {
	currentSpec, err := a.specService.Get()
	if err != nil {
		return ErrandResult{}, bosherr.WrapError(err, "Getting current spec")
	}

	if len(currentSpec.JobSpec.Template) == 0 {
		return ErrandResult{}, bosherr.New("At least one job template is required to run an errand")
	}

	command := boshsys.Command{
		Name: filepath.Join(a.jobsDir, currentSpec.JobSpec.Template, "bin", "run"),
		Env: map[string]string{
			"PATH": "/usr/sbin:/usr/bin:/sbin:/bin",
		},
	}

	process, err := a.cmdRunner.RunComplexCommandAsync(command)
	if err != nil {
		return ErrandResult{}, bosherr.WrapError(err, "Running errand script")
	}

	var result boshsys.Result

	// Can only wait once on a process but cancelling can happen multiple times
	for processExitedCh := process.Wait(); processExitedCh != nil; {
		select {
		case result = <-processExitedCh:
			processExitedCh = nil
		case <-a.cancelCh:
			// Ignore possible TerminateNicely error since we cannot return it
			err := process.TerminateNicely(10 * time.Second)
			if err != nil {
				a.logger.Error(runErrandActionLogTag, "Failed to terminate %s", err.Error())
			}
		}
	}

	if result.Error != nil && result.ExitStatus == -1 {
		return ErrandResult{}, bosherr.WrapError(result.Error, "Running errand script")
	}

	return ErrandResult{
		Stdout:     result.Stdout,
		Stderr:     result.Stderr,
		ExitStatus: result.ExitStatus,
	}, nil
}

func (a RunErrandAction) Resume() (interface{}, error) {
	return nil, errors.New("not supported")
}

// Cancelling rules:
// 1. Cancel action MUST take constant time even if another cancel is pending/running
// 2. Cancel action DOES NOT have to cancel if another cancel is pending/running
// 3. Cancelling errand before it starts should cancel errand when it runs
//    - possible optimization - do not even start errand
// (e.g. send 5 cancels, 1 is actually doing cancelling, other 4 exit immediately)

// Cancel satisfies above rules though it never returns any error
func (a RunErrandAction) Cancel() error {
	select {
	case a.cancelCh <- struct{}{}:
		// Always return no error since we cannot wait until
		// errand runs in the future and potentially fails to cancel

	default:
		// Cancel action is already queued up
	}
	return nil
}
