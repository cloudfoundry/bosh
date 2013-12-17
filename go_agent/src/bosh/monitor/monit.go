package monitor

import (
	bosherr "bosh/errors"
	boshmonit "bosh/monitor/monit"
	boshsettings "bosh/settings"
	boshsys "bosh/system"
	"fmt"
	"path/filepath"
)

type monit struct {
	fs     boshsys.FileSystem
	runner boshsys.CmdRunner
	client boshmonit.MonitClient
}

func NewMonit(fs boshsys.FileSystem, runner boshsys.CmdRunner, client boshmonit.MonitClient) (m Monitor) {
	return monit{fs: fs, runner: runner, client: client}
}

func (m monit) Reload() (err error) {
	m.runner.RunCommand("monit", "reload")
	return
}

func (m monit) Start() (err error) {
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
	}

	return
}

func (m monit) AddJob(jobName string, jobIndex int, configPath string) (err error) {
	targetFilename := fmt.Sprintf("%04d_%s.monitrc", jobIndex, jobName)
	targetConfigPath := filepath.Join(boshsettings.VCAP_MONIT_JOBS_DIR, targetFilename)

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
