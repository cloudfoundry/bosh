package monitor

type Monitor interface {
	Reload() (err error)
	Start() (err error)
	AddJob(jobName string, jobIndex int, configPath string) (err error)
}
