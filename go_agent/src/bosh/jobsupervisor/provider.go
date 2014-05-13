package jobsupervisor

import (
	"time"

	bosherr "bosh/errors"
	boshhandler "bosh/handler"
	boshmonit "bosh/jobsupervisor/monit"
	boshlog "bosh/logger"
	boshplatform "bosh/platform"
	boshdir "bosh/settings/directories"
)

type Provider struct {
	supervisors map[string]JobSupervisor
}

func NewProvider(
	platform boshplatform.Platform,
	client boshmonit.Client,
	logger boshlog.Logger,
	dirProvider boshdir.DirectoriesProvider,
	handler boshhandler.Handler,
) (p Provider) {
	monitJobSupervisor := NewMonitJobSupervisor(
		platform.GetFs(),
		platform.GetRunner(),
		client,
		logger,
		dirProvider,
		2825,
		MonitReloadOptions{
			MaxTries:               3,
			MaxCheckTries:          6,
			DelayBetweenCheckTries: 5 * time.Second,
		},
	)

	p.supervisors = map[string]JobSupervisor{
		"monit":      monitJobSupervisor,
		"dummy":      NewDummyJobSupervisor(),
		"dummy-nats": NewDummyNatsJobSupervisor(handler),
	}

	return
}

func (p Provider) Get(name string) (supervisor JobSupervisor, err error) {
	supervisor, found := p.supervisors[name]
	if !found {
		err = bosherr.New("JobSupervisor %s could not be found", name)
	}
	return
}
