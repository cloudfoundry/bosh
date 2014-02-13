package action

import (
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

func (s StartAction) Run() (value interface{}, err error) {
	err = s.jobSupervisor.Start()
	if err != nil {
		err = bosherr.WrapError(err, "Starting Monitored Services")
		return
	}

	value = "started"
	return
}
