package monitor

import boshsysstat "bosh/monitor/system_status"

type Monitor interface {
	Reload() (err error)
	Start() (err error)
	Stop() (err error)
	Status() (status string)
	SystemStatus() (status boshsysstat.SystemStatus, err error)
	AddJob(jobName string, jobIndex int, configPath string) (err error)
}
