package action

import (
	bosherr "bosh/errors"
	boshjobsuper "bosh/jobsupervisor"
)

type startAction struct {
	jobSupervisor boshjobsuper.JobSupervisor
}

func newStart(jobSupervisor boshjobsuper.JobSupervisor) (start startAction) {
	start = startAction{
		jobSupervisor: jobSupervisor,
	}
	return
}

func (a startAction) IsAsynchronous() bool {
	return false
}

func (s startAction) Run() (value interface{}, err error) {
	err = s.jobSupervisor.Start()
	if err != nil {
		err = bosherr.WrapError(err, "Starting Monitored Services")
		return
	}

	value = "started"
	return
}
