package action

import (
	"errors"

	bosherr "bosh/errors"
	boshjobsuper "bosh/jobsupervisor"
)

type StartAction struct {
	jobSupervisor boshjobsuper.JobSupervisor
}

func NewStart(jobSupervisor boshjobsuper.JobSupervisor) (start StartAction) {
	start = StartAction{
		jobSupervisor: jobSupervisor,
	}
	return
}

func (a StartAction) IsAsynchronous() bool {
	return false
}

func (a StartAction) IsPersistent() bool {
	return false
}

func (a StartAction) Run() (value string, err error) {
	err = a.jobSupervisor.Start()
	if err != nil {
		err = bosherr.WrapError(err, "Starting Monitored Services")
		return
	}

	value = "started"
	return
}

func (a StartAction) Resume() (interface{}, error) {
	return nil, errors.New("not supported")
}

func (a StartAction) Cancel() error {
	return errors.New("not supported")
}
