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

type monitJobSupervisor struct {
	fs                             boshsys.FileSystem
	runner                         boshsys.CmdRunner
	client                         boshmonit.Client
	logger                         boshlog.Logger
	dirProvider                    boshdir.DirectoriesProvider
	jobFailuresServerPort          int
	delayBetweenReloadCheckRetries time.Duration
}

const MonitTag = "Monit Job Supervisor"

func NewMonitJobSupervisor(
	fs boshsys.FileSystem,
	runner boshsys.CmdRunner,
	client boshmonit.Client,
	logger boshlog.Logger,
	dirProvider boshdir.DirectoriesProvider,
	jobFailuresServerPort int,
	delayBetweenReloadCheckRetries time.Duration,
) (m monitJobSupervisor) {
	return monitJobSupervisor{
		fs:                             fs,
		runner:                         runner,
		client:                         client,
		logger:                         logger,
		dirProvider:                    dirProvider,
		jobFailuresServerPort:          jobFailuresServerPort,
		delayBetweenReloadCheckRetries: delayBetweenReloadCheckRetries,
	}
}

func (m monitJobSupervisor) Reload() error {
	oldIncarnation, err := m.getIncarnation()
	if err != nil {
		return bosherr.WrapError(err, "Getting monit incarnation")
	}

	// Exit code or output cannot be trusted
	m.runner.RunCommand("monit", "reload")

	for attempt := 1; attempt < 60; attempt++ {
		currentIncarnation, err := m.getIncarnation()
		if err != nil {
			return bosherr.WrapError(err, "Getting monit incarnation")
		}

		if oldIncarnation < currentIncarnation {
			return nil
		}

		time.Sleep(m.delayBetweenReloadCheckRetries)
	}

	return bosherr.New("Failed to reload monit")
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
		m.logger.Debug(MonitTag, "Starting service %s", service)
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
		m.logger.Debug(MonitTag, "Stopping service %s", service)
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
		m.logger.Debug(MonitTag, "Unmonitoring service %s", service)
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
