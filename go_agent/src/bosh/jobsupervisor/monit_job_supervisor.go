package jobsupervisor

import (
	"fmt"
	"path/filepath"
	"time"

	"github.com/pivotal/go-smtpd/smtpd"

	boshalert "bosh/agent/alert"
	bosherr "bosh/errors"
	boshmonit "bosh/jobsupervisor/monit"
	boshlog "bosh/logger"
	boshdir "bosh/settings/directories"
	boshsys "bosh/system"
)

const monitJobSupervisorLogTag = "monitJobSupervisor"

type monitJobSupervisor struct {
	fs          boshsys.FileSystem
	runner      boshsys.CmdRunner
	client      boshmonit.Client
	logger      boshlog.Logger
	dirProvider boshdir.DirectoriesProvider

	jobFailuresServerPort int

	reloadOptions MonitReloadOptions
}

type MonitReloadOptions struct {
	// Number of times `monit reload` will be executed
	MaxTries int

	// Number of times monit incarnation will be checked
	// for difference after executing `monit reload`
	MaxCheckTries int

	// Length of time between checking for incarnation difference
	DelayBetweenCheckTries time.Duration
}

func NewMonitJobSupervisor(
	fs boshsys.FileSystem,
	runner boshsys.CmdRunner,
	client boshmonit.Client,
	logger boshlog.Logger,
	dirProvider boshdir.DirectoriesProvider,
	jobFailuresServerPort int,
	reloadOptions MonitReloadOptions,
) (m monitJobSupervisor) {
	return monitJobSupervisor{
		fs:          fs,
		runner:      runner,
		client:      client,
		logger:      logger,
		dirProvider: dirProvider,

		jobFailuresServerPort: jobFailuresServerPort,

		reloadOptions: reloadOptions,
	}
}

func (m monitJobSupervisor) Reload() error {
	var currentIncarnation int

	oldIncarnation, err := m.getIncarnation()
	if err != nil {
		return bosherr.WrapError(err, "Getting monit incarnation")
	}

	// Monit process could be started in the same second as `monit reload` runs
	// so it's ideal for MaxCheckTries * DelayBetweenCheckTries to be greater than 1 sec
	// because monit incarnation id is just a timestamp with 1 sec resolution.
	for reloadI := 0; reloadI < m.reloadOptions.MaxTries; reloadI++ {
		// Exit code or output cannot be trusted
		_, _, _, err := m.runner.RunCommand("monit", "reload")
		if err != nil {
			m.logger.Error(monitJobSupervisorLogTag, "Failed to reload monit %s", err.Error())
		}

		for checkI := 0; checkI < m.reloadOptions.MaxCheckTries; checkI++ {
			currentIncarnation, err = m.getIncarnation()
			if err != nil {
				return bosherr.WrapError(err, "Getting monit incarnation")
			}

			// Incarnation id can decrease or increase because
			// monit uses time(...) and system time can be changed
			if oldIncarnation != currentIncarnation {
				return nil
			}

			m.logger.Debug(
				monitJobSupervisorLogTag,
				"Waiting for monit to reload: before=%d after=%d",
				oldIncarnation, currentIncarnation,
			)

			time.Sleep(m.reloadOptions.DelayBetweenCheckTries)
		}
	}

	return bosherr.New(
		"Failed to reload monit: before=%d after=%d",
		oldIncarnation, currentIncarnation,
	)
}

func (m monitJobSupervisor) Start() error {
	services, err := m.client.ServicesInGroup("vcap")
	if err != nil {
		return bosherr.WrapError(err, "Getting vcap services")
	}

	for _, service := range services {
		err = m.client.StartService(service)
		if err != nil {
			return bosherr.WrapError(err, "Starting service %s", service)
		}
		m.logger.Debug(monitJobSupervisorLogTag, "Starting service %s", service)
	}

	return nil
}

func (m monitJobSupervisor) Stop() error {
	services, err := m.client.ServicesInGroup("vcap")
	if err != nil {
		return bosherr.WrapError(err, "Getting vcap services")
	}

	for _, service := range services {
		err = m.client.StopService(service)
		if err != nil {
			return bosherr.WrapError(err, "Stopping service %s", service)
		}
		m.logger.Debug(monitJobSupervisorLogTag, "Stopping service %s", service)
	}

	return nil
}

func (m monitJobSupervisor) Unmonitor() error {
	services, err := m.client.ServicesInGroup("vcap")
	if err != nil {
		return bosherr.WrapError(err, "Getting vcap services")
	}

	for _, service := range services {
		err := m.client.UnmonitorService(service)
		if err != nil {
			return bosherr.WrapError(err, "Unmonitoring service %s", service)
		}
		m.logger.Debug(monitJobSupervisorLogTag, "Unmonitoring service %s", service)
	}

	return nil
}

func (m monitJobSupervisor) Status() (status string) {
	status = "running"
	monitStatus, err := m.client.Status()
	if err != nil {
		status = "unknown"
		return
	}

	for _, service := range monitStatus.ServicesInGroup("vcap") {
		if service.Status == "starting" {
			return "starting"
		}
		if !service.Monitored || service.Status != "running" {
			status = "failing"
		}
	}

	return
}

func (m monitJobSupervisor) getIncarnation() (int, error) {
	monitStatus, err := m.client.Status()
	if err != nil {
		return -1, err
	}

	return monitStatus.GetIncarnation()
}

func (m monitJobSupervisor) AddJob(jobName string, jobIndex int, configPath string) error {
	targetFilename := fmt.Sprintf("%04d_%s.monitrc", jobIndex, jobName)
	targetConfigPath := filepath.Join(m.dirProvider.MonitJobsDir(), targetFilename)

	configContent, err := m.fs.ReadFile(configPath)
	if err != nil {
		return bosherr.WrapError(err, "Reading job config from file")
	}

	err = m.fs.WriteFile(targetConfigPath, configContent)
	if err != nil {
		return bosherr.WrapError(err, "Writing to job config file")
	}

	return nil
}

func (m monitJobSupervisor) RemoveAllJobs() error {
	return m.fs.RemoveAll(m.dirProvider.MonitJobsDir())
}

func (m monitJobSupervisor) MonitorJobFailures(handler JobFailureHandler) (err error) {
	alertHandler := func(smtpd.Connection, smtpd.MailAddress) (env smtpd.Envelope, err error) {
		env = &alertEnvelope{
			new(smtpd.BasicEnvelope),
			handler,
			new(boshalert.MonitAlert),
		}
		return
	}

	serv := &smtpd.Server{
		Addr:      fmt.Sprintf(":%d", m.jobFailuresServerPort),
		OnNewMail: alertHandler,
	}

	err = serv.ListenAndServe()
	if err != nil {
		err = bosherr.WrapError(err, "Listen for SMTP")
	}
	return
}
