package fakes

type FakeMonitor struct {
	Reloaded  bool
	ReloadErr error

	AddJobArgs []AddJobArgs
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
