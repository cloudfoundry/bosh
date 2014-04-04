package jobsupervisor

import (
	"encoding/json"

	boshhandler "bosh/handler"
)

type dummyNatsJobSupervisor struct {
	mbusHandler boshhandler.Handler
	status      string
}

func NewDummyNatsJobSupervisor(mbusHandler boshhandler.Handler) *dummyNatsJobSupervisor {
	return &dummyNatsJobSupervisor{
		mbusHandler: mbusHandler,
		status:      "running",
	}
}

func (d *dummyNatsJobSupervisor) Reload() error {
	return nil
}

func (d *dummyNatsJobSupervisor) AddJob(jobName string, jobIndex int, configPath string) error {
	return nil
}

func (d *dummyNatsJobSupervisor) Start() error {
	return nil
}

func (d *dummyNatsJobSupervisor) Stop() error {
	return nil
}

func (d *dummyNatsJobSupervisor) Unmonitor() error {
	return nil
}

func (d *dummyNatsJobSupervisor) RemoveAllJobs() error {
	return nil
}

func (d *dummyNatsJobSupervisor) Status() string {
	return d.status
}

func (d *dummyNatsJobSupervisor) MonitorJobFailures(handler JobFailureHandler) error {
	d.mbusHandler.Run(d.statusHandler)
	return nil
}

func (d *dummyNatsJobSupervisor) statusHandler(req boshhandler.Request) boshhandler.Response {
	if req.Method != "set_dummy_status" {
		return nil
	}

	var body map[string]string
	json.Unmarshal(req.GetPayload(), &body)
	d.status = body["status"]

	return nil
}
