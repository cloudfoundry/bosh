package jobsupervisor_test

import (
	boshalert "bosh/agent/alert"
	. "bosh/jobsupervisor"
	boshmonit "bosh/jobsupervisor/monit"
	fakemonit "bosh/jobsupervisor/monit/fakes"
	boshlog "bosh/logger"
	boshdir "bosh/settings/directories"
	fakesys "bosh/system/fakes"
	"bytes"
	"errors"
	"fmt"
	. "github.com/onsi/ginkgo"
	"github.com/stretchr/testify/assert"
	"net/smtp"
)

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
	fs                    *fakesys.FakeFileSystem
	runner                *fakesys.FakeCmdRunner
	client                *fakemonit.FakeMonitClient
	logger                boshlog.Logger
	dirProvider           boshdir.DirectoriesProvider
	jobFailuresServerPort int
}

func buildMonitJobSupervisor() (deps monitJobSupDeps, monit JobSupervisor) {
	deps = monitJobSupDeps{
		fs:                    &fakesys.FakeFileSystem{},
		runner:                &fakesys.FakeCmdRunner{},
		client:                fakemonit.NewFakeMonitClient(),
		logger:                boshlog.NewLogger(boshlog.LEVEL_NONE),
		dirProvider:           boshdir.NewDirectoriesProvider("/var/vcap"),
		jobFailuresServerPort: getJobFailureServerPort(),
	}

	monit = NewMonitJobSupervisor(deps.fs, deps.runner, deps.client, deps.logger, deps.dirProvider, deps.jobFailuresServerPort)
	return
}

var jobFailureServerPort int = 5000

func getJobFailureServerPort() int {
	jobFailureServerPort++
	return jobFailureServerPort
}
func init() {
	Describe("Testing with Ginkgo", func() {
		It("reload", func() {
			deps, monit := buildMonitJobSupervisor()
			err := monit.Reload()

			assert.NoError(GinkgoT(), err)
			assert.Equal(GinkgoT(), 1, len(deps.runner.RunCommands))
			assert.Equal(GinkgoT(), []string{"monit", "reload"}, deps.runner.RunCommands[0])
		})
		It("start starts each monit service in group vcap", func() {

			deps, monit := buildMonitJobSupervisor()

			deps.client.ServicesInGroupServices = []string{"fake-service"}

			err := monit.Start()
			assert.NoError(GinkgoT(), err)

			assert.Equal(GinkgoT(), "vcap", deps.client.ServicesInGroupName)
			assert.Equal(GinkgoT(), 1, len(deps.client.StartServiceNames))
			assert.Equal(GinkgoT(), "fake-service", deps.client.StartServiceNames[0])
		})
		It("stop stops each monit service in group vcap", func() {

			deps, monit := buildMonitJobSupervisor()

			deps.client.ServicesInGroupServices = []string{"fake-service"}

			err := monit.Stop()
			assert.NoError(GinkgoT(), err)

			assert.Equal(GinkgoT(), "vcap", deps.client.ServicesInGroupName)
			assert.Equal(GinkgoT(), 1, len(deps.client.StopServiceNames))
			assert.Equal(GinkgoT(), "fake-service", deps.client.StopServiceNames[0])
		})
		It("add job", func() {

			deps, monit := buildMonitJobSupervisor()
			deps.fs.WriteToFile("/some/config/path", "some config content")
			monit.AddJob("router", 0, "/some/config/path")

			writtenConfig, err := deps.fs.ReadFile(deps.dirProvider.MonitJobsDir() + "/0000_router.monitrc")
			assert.NoError(GinkgoT(), err)
			assert.Equal(GinkgoT(), writtenConfig, "some config content")
		})
		It("status returns running when all services are monitored and running", func() {

			deps, monit := buildMonitJobSupervisor()

			deps.client.StatusStatus = &fakemonit.FakeMonitStatus{
				Services: []boshmonit.Service{
					boshmonit.Service{Monitored: true, Status: "running"},
					boshmonit.Service{Monitored: true, Status: "running"},
				},
			}

			status := monit.Status()
			assert.Equal(GinkgoT(), "running", status)
		})
		It("status returns failing when all services are monitored and at least one service is failing", func() {

			deps, monit := buildMonitJobSupervisor()

			deps.client.StatusStatus = &fakemonit.FakeMonitStatus{
				Services: []boshmonit.Service{
					boshmonit.Service{Monitored: true, Status: "failing"},
					boshmonit.Service{Monitored: true, Status: "running"},
				},
			}

			status := monit.Status()
			assert.Equal(GinkgoT(), "failing", status)
		})
		It("status returns failing when at least one service is not monitored", func() {

			deps, monit := buildMonitJobSupervisor()

			deps.client.StatusStatus = &fakemonit.FakeMonitStatus{
				Services: []boshmonit.Service{
					boshmonit.Service{Monitored: false, Status: "running"},
					boshmonit.Service{Monitored: true, Status: "running"},
				},
			}

			status := monit.Status()
			assert.Equal(GinkgoT(), "failing", status)
		})
		It("status returns start when at least one service is starting", func() {

			deps, monit := buildMonitJobSupervisor()

			deps.client.StatusStatus = &fakemonit.FakeMonitStatus{
				Services: []boshmonit.Service{
					boshmonit.Service{Monitored: true, Status: "failing"},
					boshmonit.Service{Monitored: true, Status: "starting"},
					boshmonit.Service{Monitored: true, Status: "running"},
				},
			}

			status := monit.Status()
			assert.Equal(GinkgoT(), "starting", status)
		})
		It("status returns unknown when error", func() {

			deps, monit := buildMonitJobSupervisor()

			deps.client.StatusErr = errors.New("fake-monit-client-error")

			status := monit.Status()
			assert.Equal(GinkgoT(), "unknown", status)
		})
		It("monitor job failures", func() {

			var handledAlert boshalert.MonitAlert

			failureHandler := func(alert boshalert.MonitAlert) (err error) {
				handledAlert = alert
				return
			}

			deps, monit := buildMonitJobSupervisor()

			go monit.MonitorJobFailures(failureHandler)

			msg := `Message-id: <1304319946.0@localhost>
    Service: nats
    Event: does not exist
    Action: restart
    Date: Sun, 22 May 2011 20:07:41 +0500
    Description: process is not running`

			err := doJobFailureEmail(msg, deps.jobFailuresServerPort)
			assert.NoError(GinkgoT(), err)

			assert.Equal(GinkgoT(), handledAlert, boshalert.MonitAlert{
				Id:          "1304319946.0@localhost",
				Service:     "nats",
				Event:       "does not exist",
				Action:      "restart",
				Date:        "Sun, 22 May 2011 20:07:41 +0500",
				Description: "process is not running",
			})
		})
		It("monitor job failures ignores other emails", func() {

			var didHandleAlert bool

			failureHandler := func(alert boshalert.MonitAlert) (err error) {
				didHandleAlert = true
				return
			}

			deps, monit := buildMonitJobSupervisor()

			go monit.MonitorJobFailures(failureHandler)

			msg := `Hi! How'sit goin`

			err := doJobFailureEmail(msg, deps.jobFailuresServerPort)
			assert.NoError(GinkgoT(), err)
			assert.False(GinkgoT(), didHandleAlert)
		})
	})
}
