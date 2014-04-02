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

	// Start and Stop should still function after Unmonitor.
	// Calling Start after Unmonitor should re-monitor all jobs.
	// Calling Stop after Unmonitor should not re-monitor all jobs.
	// (Monit complies to above requirements.)
	Unmonitor() error

	Status() string

	// Job management
	AddJob(jobName string, jobIndex int, configPath string) error
	RemoveAllJobs() error

	MonitorJobFailures(handler JobFailureHandler) error
}
