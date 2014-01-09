package jobsupervisor

type dummyJobSupervisor struct {
	status string
}

func newDummyJobSupervisor() (supervisor *dummyJobSupervisor) {
	supervisor = &dummyJobSupervisor{
		status: "unknown",
	}
	return
}

func (s *dummyJobSupervisor) Reload() (err error) {
	return
}

func (s *dummyJobSupervisor) Start() (err error) {
	s.status = "running"
	return
}

func (s *dummyJobSupervisor) Stop() (err error) {
	s.status = "failing"
	return
}

func (s *dummyJobSupervisor) Status() (status string) {
	return s.status
}

func (s *dummyJobSupervisor) AddJob(jobName string, jobIndex int, configPath string) (err error) {
	return
}

func (s *dummyJobSupervisor) MonitorJobFailures(handler JobFailureHandler) (err error) {
	return
}
