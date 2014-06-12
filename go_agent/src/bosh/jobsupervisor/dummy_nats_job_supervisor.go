package jobsupervisor

import (
	"encoding/json"

	boshalert "bosh/agent/alert"
	boshhandler "bosh/handler"
)

type dummyNatsJobSupervisor struct {
	mbusHandler       boshhandler.Handler
	status            string
	jobFailureHandler JobFailureHandler
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
	d.jobFailureHandler = handler

	d.mbusHandler.RegisterAdditionalHandlerFunc(d.statusHandler)

	return nil
}

func (d *dummyNatsJobSupervisor) statusHandler(req boshhandler.Request) boshhandler.Response {
	switch req.Method {
	case "set_dummy_status":
		// Do not unmarshal message until determining its method
		var body map[string]string

		err := json.Unmarshal(req.GetPayload(), &body)
		if err != nil {
			return boshhandler.NewExceptionResponse(err)
		}

		d.status = body["status"]

		if d.status == "failing" && d.jobFailureHandler != nil {
			d.jobFailureHandler(boshalert.MonitAlert{
				ID:          "fake-monit-alert",
				Service:     "fake-monit-service",
				Event:       "failing",
				Action:      "start",
				Date:        "Sun, 22 May 2011 20:07:41 +0500",
				Description: "fake-monit-description",
			})
		}

		return boshhandler.NewValueResponse("ok")
	default:
		return nil
	}
}
