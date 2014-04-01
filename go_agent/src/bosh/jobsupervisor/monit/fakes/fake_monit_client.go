package fakes

import (
	boshmonit "bosh/jobsupervisor/monit"
)

type FakeMonitClient struct {
	ServicesInGroupName     string
	ServicesInGroupServices []string
	ServicesInGroupErr      error

	StartServiceNames []string
	StartServiceErr   error

	StopServiceNames []string
	StopServiceErr   error

	UnmonitorServiceNames []string
	UnmonitorServiceErrs  []error

	StatusStatus FakeMonitStatus
	StatusErr    error

	Incarnations      []int
	StatusCalledTimes int
}

func NewFakeMonitClient() *FakeMonitClient {
	return &FakeMonitClient{}
}

func (c *FakeMonitClient) ServicesInGroup(name string) ([]string, error) {
	c.ServicesInGroupName = name
	return c.ServicesInGroupServices, c.ServicesInGroupErr
}

func (c *FakeMonitClient) StartService(name string) error {
	c.StartServiceNames = append(c.StartServiceNames, name)
	return c.StartServiceErr
}

func (c *FakeMonitClient) StopService(name string) error {
	c.StopServiceNames = append(c.StopServiceNames, name)
	return c.StopServiceErr
}

func (c *FakeMonitClient) UnmonitorService(name string) error {
	c.UnmonitorServiceNames = append(c.UnmonitorServiceNames, name)
	return c.UnmonitorServiceErrs[len(c.UnmonitorServiceNames)-1]
}

func (c *FakeMonitClient) Status() (boshmonit.Status, error) {
	s := c.StatusStatus
	if len(c.Incarnations) > 0 {
		s.Incarnation = c.Incarnations[c.StatusCalledTimes]
	}

	c.StatusCalledTimes++

	return s, c.StatusErr
}
