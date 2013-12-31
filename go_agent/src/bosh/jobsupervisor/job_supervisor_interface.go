package jobsupervisor

import boshsysstat "bosh/jobsupervisor/system_status"

type JobSupervisor interface {
	Reload() (err error)
	Start() (err error)
	Stop() (err error)
	Status() (status string)
	SystemStatus() (status boshsysstat.SystemStatus, err error)
	AddJob(jobName string, jobIndex int, configPath string) (err error)
}
