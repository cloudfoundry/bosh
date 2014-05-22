package action

import (
	"errors"

	bosherr "bosh/errors"
	boshjobsuper "bosh/jobsupervisor"
)

type StopAction struct {
	jobSupervisor boshjobsuper.JobSupervisor
}

func NewStop(jobSupervisor boshjobsuper.JobSupervisor) (stop StopAction) {
	stop = StopAction{
		jobSupervisor: jobSupervisor,
	}
	return
}

func (a StopAction) IsAsynchronous() bool {
	return true
}

func (a StopAction) IsPersistent() bool {
	return false
}

func (a StopAction) Run() (value string, err error) {
	err = a.jobSupervisor.Stop()
	if err != nil {
		err = bosherr.WrapError(err, "Stopping Monitored Services")
		return
	}

	value = "stopped"
	return
}

func (a StopAction) Resume() (interface{}, error) {
	return nil, errors.New("not supported")
}

func (a StopAction) Cancel() error {
	return errors.New("not supported")
}
