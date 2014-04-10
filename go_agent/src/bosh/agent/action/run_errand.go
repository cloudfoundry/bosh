package action

import (
	"errors"
	"path/filepath"

	boshas "bosh/agent/applier/applyspec"
	bosherr "bosh/errors"
	boshsys "bosh/system"
)

type RunErrandAction struct {
	specService boshas.V1Service
	jobsDir     string
	cmdRunner   boshsys.CmdRunner
}

func NewRunErrand(
	specService boshas.V1Service,
	jobsDir string,
	cmdRunner boshsys.CmdRunner,
) RunErrandAction {
	return RunErrandAction{
		specService: specService,
		jobsDir:     jobsDir,
		cmdRunner:   cmdRunner,
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

	stdout, stderr, exitStatus, err := a.cmdRunner.RunComplexCommand(command)
	if err != nil && exitStatus == -1 {
		return ErrandResult{}, bosherr.WrapError(err, "Running errand script")
	}

	return ErrandResult{
		Stdout:     stdout,
		Stderr:     stderr,
		ExitStatus: exitStatus,
	}, nil
}

func (a RunErrandAction) Resume() (interface{}, error) {
	return nil, errors.New("not supported")
}
