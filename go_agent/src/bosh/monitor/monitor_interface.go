package monitor

type Monitor interface {
	Reload() (err error)
	Start() (err error)
	Stop() (err error)
	Status() (status string)
	AddJob(jobName string, jobIndex int, configPath string) (err error)
}
