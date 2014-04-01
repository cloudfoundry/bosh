package jobsupervisor

import (
	boshalert "bosh/agent/alert"
)

type JobFailureHandler func(boshalert.MonitAlert) error

type JobSupervisor interface {
	Reload() error

	// Actions taken on all services
	Start() error
	Stop() error
	Unmonitor() error

	Status() string

	AddJob(jobName string, jobIndex int, configPath string) error

	MonitorJobFailures(handler JobFailureHandler) error
}
