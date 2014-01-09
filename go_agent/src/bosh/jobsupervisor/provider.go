package jobsupervisor

import (
	bosherr "bosh/errors"
	boshmonit "bosh/jobsupervisor/monit"
	boshlog "bosh/logger"
	boshplatform "bosh/platform"
	boshdir "bosh/settings/directories"
)

type provider struct {
	supervisors map[string]JobSupervisor
}

func NewProvider(
	platform boshplatform.Platform,
	client boshmonit.Client,
	logger boshlog.Logger,
	dirProvider boshdir.DirectoriesProvider,
) (p provider) {

	p.supervisors = map[string]JobSupervisor{
		"monit": NewMonitJobSupervisor(platform.GetFs(), platform.GetRunner(), client, logger, dirProvider),
		"dummy": newDummyJobSupervisor(),
	}

	return
}

func (p provider) Get(name string) (supervisor JobSupervisor, err error) {
	supervisor, found := p.supervisors[name]

	if !found {
		err = bosherr.New("JobSupervisor %s could not be found", name)
	}
	return
}
