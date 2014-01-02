package fakes

import (
	boshmonit "bosh/jobsupervisor/monit"
)

type FakeMonitStatus struct {
	Services []boshmonit.Service
}

func (s *FakeMonitStatus) ServicesInGroup(name string) (services []boshmonit.Service) {
	services = s.Services
	return
}
