package jobsupervisor

import boshalert "bosh/agent/alert"

type JobFailureHandler func(boshalert.MonitAlert) error

type JobSupervisor interface {
	Reload() (err error)
	Start() (err error)
	Stop() (err error)
	Status() (status string)
	AddJob(jobName string, jobIndex int, configPath string) (err error)
	MonitorJobFailures(handler JobFailureHandler) (err error)
}
