package fakes

import (
	boshjobsup "bosh/jobsupervisor"
)

type FakeJobSupervisor struct {
	Reloaded  bool
	ReloadErr error

	AddJobArgs []AddJobArgs

	Started  bool
	StartErr error

	Stopped bool
	StopErr error

	Unmonitored  bool
	UnmonitorErr error

	StatusStatus string

	OnJobFailure boshjobsup.JobFailureHandler
}

type AddJobArgs struct {
	Name       string
	Index      int
	ConfigPath string
}

func NewFakeJobSupervisor() *FakeJobSupervisor {
	return &FakeJobSupervisor{}
}

func (m *FakeJobSupervisor) Reload() error {
	m.Reloaded = true
	return m.ReloadErr
}

func (m *FakeJobSupervisor) AddJob(jobName string, jobIndex int, configPath string) error {
	args := AddJobArgs{
		Name:       jobName,
		Index:      jobIndex,
		ConfigPath: configPath,
	}
	m.AddJobArgs = append(m.AddJobArgs, args)
	return nil
}

func (m *FakeJobSupervisor) Start() error {
	m.Started = true
	return m.StartErr
}

func (m *FakeJobSupervisor) Stop() error {
	m.Stopped = true
	return m.StopErr
}

func (m *FakeJobSupervisor) Unmonitor() error {
	m.Stopped = true
	return m.StopErr
}

func (m *FakeJobSupervisor) Status() string {
	return m.StatusStatus
}

func (m *FakeJobSupervisor) MonitorJobFailures(handler boshjobsup.JobFailureHandler) error {
	m.OnJobFailure = handler
	return nil
}
