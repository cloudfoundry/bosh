package monit

import boshsysstat "bosh/jobsupervisor/system_status"

type Status interface {
	ServicesInGroup(name string) (services []Service)
	SystemStatus() (systemStatus boshsysstat.SystemStatus)
}

type Service struct {
	Monitored bool
	Status    string
}
