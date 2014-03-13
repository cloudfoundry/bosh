package fakes

import (
	boshmonit "bosh/jobsupervisor/monit"
)

type FakeMonitStatus struct {
	Incarnation int
	Services    []boshmonit.Service
}

func (s FakeMonitStatus) ServicesInGroup(name string) (services []boshmonit.Service) {
	services = s.Services
	return
}

func (s FakeMonitStatus) GetIncarnation() (int, error) {
	return s.Incarnation, nil
}
