package jobsupervisor

type dummyJobSupervisor struct {
	status string
}

func NewDummyJobSupervisor() *dummyJobSupervisor {
	return &dummyJobSupervisor{status: "unknown"}
}

func (s *dummyJobSupervisor) Reload() error {
	return nil
}

func (s *dummyJobSupervisor) Start() error {
	s.status = "running"
	return nil
}

func (s *dummyJobSupervisor) Stop() error {
	s.status = "failing"
	return nil
}

func (s *dummyJobSupervisor) Unmonitor() error {
	return nil
}

func (s *dummyJobSupervisor) Status() (status string) {
	return s.status
}

func (s *dummyJobSupervisor) AddJob(jobName string, jobIndex int, configPath string) error {
	return nil
}

func (s *dummyJobSupervisor) RemoveAllJobs() error {
	return nil
}

func (s *dummyJobSupervisor) MonitorJobFailures(handler JobFailureHandler) error {
	return nil
}
