package action

import (
	bosherr "bosh/errors"
	boshjobsuper "bosh/jobsupervisor"
)

type stopAction struct {
	jobSupervisor boshjobsuper.JobSupervisor
}

func newStop(jobSupervisor boshjobsuper.JobSupervisor) (stop stopAction) {
	stop = stopAction{
		jobSupervisor: jobSupervisor,
	}
	return
}

func (a stopAction) IsAsynchronous() bool {
	return true
}

func (s stopAction) Run() (value interface{}, err error) {
	err = s.jobSupervisor.Stop()
	if err != nil {
		err = bosherr.WrapError(err, "Stopping Monitored Services")
		return
	}

	value = "stopped"
	return
}
