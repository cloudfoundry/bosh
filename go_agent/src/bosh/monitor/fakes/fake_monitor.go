package fakes

import boshsysstat "bosh/monitor/system_status"

type FakeMonitor struct {
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

func NewFakeMonitor() (monitor *FakeMonitor) {
	monitor = &FakeMonitor{}
	return
}

func (m *FakeMonitor) Reload() (err error) {
	m.Reloaded = true
	err = m.ReloadErr
	return
}

func (m *FakeMonitor) AddJob(jobName string, jobIndex int, configPath string) (err error) {
	args := AddJobArgs{
		Name:       jobName,
		Index:      jobIndex,
		ConfigPath: configPath,
	}
	m.AddJobArgs = append(m.AddJobArgs, args)
	return
}

func (m *FakeMonitor) Start() (err error) {
	m.Started = true
	err = m.StartErr
	return
}

func (m *FakeMonitor) Stop() (err error) {
	m.Stopped = true
	err = m.StopErr
	return
}

func (m *FakeMonitor) Status() (status string) {
	status = m.StatusStatus
	return
}

func (m *FakeMonitor) SystemStatus() (status boshsysstat.SystemStatus, err error) {
	return
}
