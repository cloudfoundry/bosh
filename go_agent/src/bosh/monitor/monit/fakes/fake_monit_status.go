package fakes

import (
	boshmonit "bosh/monitor/monit"
	boshsysstat "bosh/monitor/system_status"
)

type FakeMonitStatus struct {
	Services           []boshmonit.Service
	SystemStatusStatus boshsysstat.SystemStatus
}

func (s *FakeMonitStatus) ServicesInGroup(name string) (services []boshmonit.Service) {
	services = s.Services
	return
}

func (s *FakeMonitStatus) SystemStatus() (systemStatus boshsysstat.SystemStatus) {
	systemStatus = s.SystemStatusStatus
	return
}
