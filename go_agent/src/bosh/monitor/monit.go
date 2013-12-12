package monitor

type monit struct {
}

func NewMonit() (m Monitor) {
	return monit{}
}

func (m monit) Reload() (err error) {
	return
}

func (m monit) AddJob(jobName string, jobIndex int, configPath string) (err error) {
	return
}
