package jobsupervisor

import (
	boshalert "bosh/agent/alert"
	boshmonit "bosh/jobsupervisor/monit"
	fakemonit "bosh/jobsupervisor/monit/fakes"
	boshlog "bosh/logger"
	boshdir "bosh/settings/directories"
	fakesys "bosh/system/fakes"
	"bytes"
	"errors"
	"fmt"
	"github.com/stretchr/testify/assert"
	"net/smtp"
	"testing"
)

func TestReload(t *testing.T) {
	deps, monit := buildMonitJobSupervisor()
	err := monit.Reload()

	assert.NoError(t, err)
	assert.Equal(t, 1, len(deps.runner.RunCommands))
	assert.Equal(t, []string{"monit", "reload"}, deps.runner.RunCommands[0])
}

func TestStartStartsEachMonitServiceInGroupVcap(t *testing.T) {
	deps, monit := buildMonitJobSupervisor()

	deps.client.ServicesInGroupServices = []string{"fake-service"}

	err := monit.Start()
	assert.NoError(t, err)

	assert.Equal(t, "vcap", deps.client.ServicesInGroupName)
	assert.Equal(t, 1, len(deps.client.StartServiceNames))
	assert.Equal(t, "fake-service", deps.client.StartServiceNames[0])
}

func TestStopStopsEachMonitServiceInGroupVcap(t *testing.T) {
	deps, monit := buildMonitJobSupervisor()

	deps.client.ServicesInGroupServices = []string{"fake-service"}

	err := monit.Stop()
	assert.NoError(t, err)

	assert.Equal(t, "vcap", deps.client.ServicesInGroupName)
	assert.Equal(t, 1, len(deps.client.StopServiceNames))
	assert.Equal(t, "fake-service", deps.client.StopServiceNames[0])
}

func TestAddJob(t *testing.T) {
	deps, monit := buildMonitJobSupervisor()
	deps.fs.WriteToFile("/some/config/path", "some config content")
	monit.AddJob("router", 0, "/some/config/path")

	writtenConfig, err := deps.fs.ReadFile(monit.dirProvider.MonitJobsDir() + "/0000_router.monitrc")
	assert.NoError(t, err)
	assert.Equal(t, writtenConfig, "some config content")
}

func TestStatusReturnsRunningWhenAllServicesAreMonitoredAndRunning(t *testing.T) {
	deps, monit := buildMonitJobSupervisor()

	deps.client.StatusStatus = &fakemonit.FakeMonitStatus{
		Services: []boshmonit.Service{
			boshmonit.Service{Monitored: true, Status: "running"},
			boshmonit.Service{Monitored: true, Status: "running"},
		},
	}

	status := monit.Status()
	assert.Equal(t, "running", status)
}

func TestStatusReturnsFailingWhenAllServicesAreMonitoredAndAtLeastOneServiceIsFailing(t *testing.T) {
	deps, monit := buildMonitJobSupervisor()

	deps.client.StatusStatus = &fakemonit.FakeMonitStatus{
		Services: []boshmonit.Service{
			boshmonit.Service{Monitored: true, Status: "failing"},
			boshmonit.Service{Monitored: true, Status: "running"},
		},
	}

	status := monit.Status()
	assert.Equal(t, "failing", status)
}

func TestStatusReturnsFailingWhenAtLeastOneServiceIsNotMonitored(t *testing.T) {
	deps, monit := buildMonitJobSupervisor()

	deps.client.StatusStatus = &fakemonit.FakeMonitStatus{
		Services: []boshmonit.Service{
			boshmonit.Service{Monitored: false, Status: "running"},
			boshmonit.Service{Monitored: true, Status: "running"},
		},
	}

	status := monit.Status()
	assert.Equal(t, "failing", status)
}

func TestStatusReturnsStartWhenAtLeastOneServiceIsStarting(t *testing.T) {
	deps, monit := buildMonitJobSupervisor()

	deps.client.StatusStatus = &fakemonit.FakeMonitStatus{
		Services: []boshmonit.Service{
			boshmonit.Service{Monitored: true, Status: "failing"},
			boshmonit.Service{Monitored: true, Status: "starting"},
			boshmonit.Service{Monitored: true, Status: "running"},
		},
	}

	status := monit.Status()
	assert.Equal(t, "starting", status)
}

func TestStatusReturnsUnknownWhenError(t *testing.T) {
	deps, monit := buildMonitJobSupervisor()

	deps.client.StatusErr = errors.New("fake-monit-client-error")

	status := monit.Status()
	assert.Equal(t, "unknown", status)
}

func TestMonitorJobFailures(t *testing.T) {
	var handledAlert boshalert.MonitAlert

	failureHandler := func(alert boshalert.MonitAlert) (err error) {
		handledAlert = alert
		return
	}

	_, monit := buildMonitJobSupervisor()

	monit.jobFailuresServerPort = getJobFailureServerPort()
	go monit.MonitorJobFailures(failureHandler)

	msg := `Message-id: <1304319946.0@localhost>
    Service: nats
    Event: does not exist
    Action: restart
    Date: Sun, 22 May 2011 20:07:41 +0500
    Description: process is not running`

	err := doJobFailureEmail(msg, monit.jobFailuresServerPort)
	assert.NoError(t, err)

	assert.Equal(t, handledAlert, boshalert.MonitAlert{
		Id:          "1304319946.0@localhost",
		Service:     "nats",
		Event:       "does not exist",
		Action:      "restart",
		Date:        "Sun, 22 May 2011 20:07:41 +0500",
		Description: "process is not running",
	})
}

func TestMonitorJobFailuresIgnoresOtherEmails(t *testing.T) {
	var didHandleAlert bool

	failureHandler := func(alert boshalert.MonitAlert) (err error) {
		didHandleAlert = true
		return
	}

	_, monit := buildMonitJobSupervisor()

	monit.jobFailuresServerPort = getJobFailureServerPort()
	go monit.MonitorJobFailures(failureHandler)

	msg := `Hi! How'sit goin`

	err := doJobFailureEmail(msg, monit.jobFailuresServerPort)
	assert.NoError(t, err)
	assert.False(t, didHandleAlert)
}

func doJobFailureEmail(email string, port int) (err error) {
	email = fmt.Sprintf("%s\r\n", email)

	conn, err := smtp.Dial(fmt.Sprintf("localhost:%d", port))
	for err != nil {
		conn, err = smtp.Dial(fmt.Sprintf("localhost:%d", port))
	}

	conn.Mail("sender@example.org")
	conn.Rcpt("recipient@example.net")
	writeCloser, err := conn.Data()
	if err != nil {
		return
	}

	defer writeCloser.Close()

	buf := bytes.NewBufferString(email)
	buf.WriteTo(writeCloser)
	return
}

type monitJobSupDeps struct {
	fs          *fakesys.FakeFileSystem
	runner      *fakesys.FakeCmdRunner
	client      *fakemonit.FakeMonitClient
	logger      boshlog.Logger
	dirProvider boshdir.DirectoriesProvider
}

func buildMonitJobSupervisor() (deps monitJobSupDeps, monit monitJobSupervisor) {
	deps = monitJobSupDeps{
		fs:          &fakesys.FakeFileSystem{},
		runner:      &fakesys.FakeCmdRunner{},
		client:      fakemonit.NewFakeMonitClient(),
		logger:      boshlog.NewLogger(boshlog.LEVEL_NONE),
		dirProvider: boshdir.NewDirectoriesProvider("/var/vcap"),
	}

	monit = NewMonitJobSupervisor(deps.fs, deps.runner, deps.client, deps.logger, deps.dirProvider)
	return
}

var jobFailureServerPort int = 5000

func getJobFailureServerPort() int {
	jobFailureServerPort++
	return jobFailureServerPort
}
