package fakes

import boshsysstat "bosh/jobsupervisor/system_status"

type FakeJobSupervisor struct {
	Reloaded  bool
	ReloadErr error

	AddJobArgs []AddJobArgs

	Started  bool
	StartErr error

	Stopped bool
	StopErr error

	StatusStatus string
}

type AddJobArgs struct {
	Name       string
	Index      int
	ConfigPath string
}

func NewFakeJobSupervisor() (jobSupervisor *FakeJobSupervisor) {
	jobSupervisor = &FakeJobSupervisor{}
	return
}

func (m *FakeJobSupervisor) Reload() (err error) {
	m.Reloaded = true
	err = m.ReloadErr
	return
}

func (m *FakeJobSupervisor) AddJob(jobName string, jobIndex int, configPath string) (err error) {
	args := AddJobArgs{
		Name:       jobName,
		Index:      jobIndex,
		ConfigPath: configPath,
	}
	m.AddJobArgs = append(m.AddJobArgs, args)
	return
}

func (m *FakeJobSupervisor) Start() (err error) {
	m.Started = true
	err = m.StartErr
	return
}

func (m *FakeJobSupervisor) Stop() (err error) {
	m.Stopped = true
	err = m.StopErr
	return
}

func (m *FakeJobSupervisor) Status() (status string) {
	status = m.StatusStatus
	return
}

func (m *FakeJobSupervisor) SystemStatus() (status boshsysstat.SystemStatus, err error) {
	return
}
