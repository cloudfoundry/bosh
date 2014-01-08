package jobsupervisor

import (
	boshalert "bosh/agent/alert"
	bosherr "bosh/errors"
	boshmonit "bosh/jobsupervisor/monit"
	boshlog "bosh/logger"
	boshdir "bosh/settings/directories"
	boshsys "bosh/system"
	"fmt"
	"github.com/pivotal/go-smtpd/smtpd"
	"path/filepath"
)

type monitJobSupervisor struct {
	fs                    boshsys.FileSystem
	runner                boshsys.CmdRunner
	client                boshmonit.Client
	logger                boshlog.Logger
	dirProvider           boshdir.DirectoriesProvider
	jobFailuresServerPort int
}

const MonitTag = "Monit Job Supervisor"

func NewMonitJobSupervisor(
	fs boshsys.FileSystem,
	runner boshsys.CmdRunner,
	client boshmonit.Client,
	logger boshlog.Logger,
	dirProvider boshdir.DirectoriesProvider,
) (m monitJobSupervisor) {
	return monitJobSupervisor{
		fs:                    fs,
		runner:                runner,
		client:                client,
		logger:                logger,
		dirProvider:           dirProvider,
		jobFailuresServerPort: 2825,
	}
}

func (m monitJobSupervisor) Reload() (err error) {
	m.runner.RunCommand("monit", "reload")
	return
}

func (m monitJobSupervisor) Start() (err error) {
	services, err := m.client.ServicesInGroup("vcap")
	if err != nil {
		err = bosherr.WrapError(err, "Getting vcap services")
		return
	}

	for _, service := range services {
		err = m.client.StartService(service)
		if err != nil {
			err = bosherr.WrapError(err, "Starting service %s", service)
			return
		}
		m.logger.Debug(MonitTag, "Starting service %s", service)
	}

	return
}

func (m monitJobSupervisor) Stop() (err error) {
	services, err := m.client.ServicesInGroup("vcap")
	if err != nil {
		err = bosherr.WrapError(err, "Getting vcap services")
		return
	}

	for _, service := range services {
		err = m.client.StopService(service)
		if err != nil {
			err = bosherr.WrapError(err, "Stopping service %s", service)
			return
		}
		m.logger.Debug(MonitTag, "Stopping service %s", service)
	}

	return
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

func (m monitJobSupervisor) AddJob(jobName string, jobIndex int, configPath string) (err error) {
	targetFilename := fmt.Sprintf("%04d_%s.monitrc", jobIndex, jobName)
	targetConfigPath := filepath.Join(m.dirProvider.MonitJobsDir(), targetFilename)

	configContent, err := m.fs.ReadFile(configPath)
	if err != nil {
		err = bosherr.WrapError(err, "Reading job config from file")
		return
	}

	_, err = m.fs.WriteToFile(targetConfigPath, configContent)
	if err != nil {
		err = bosherr.WrapError(err, "Writing to job config file")
	}
	return
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
