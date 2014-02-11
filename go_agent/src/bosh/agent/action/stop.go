package action

import (
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

func (s StopAction) Run() (value interface{}, err error) {
	err = s.jobSupervisor.Stop()
	if err != nil {
		err = bosherr.WrapError(err, "Stopping Monitored Services")
		return
	}

	value = "stopped"
	return
}
