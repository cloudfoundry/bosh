package jobsupervisor_test

import (
	"bytes"
	"errors"
	"fmt"
	"net/smtp"
	"time"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
	"github.com/stretchr/testify/assert"

	boshalert "bosh/agent/alert"
	. "bosh/jobsupervisor"
	boshmonit "bosh/jobsupervisor/monit"
	fakemonit "bosh/jobsupervisor/monit/fakes"
	boshlog "bosh/logger"
	boshdir "bosh/settings/directories"
	fakesys "bosh/system/fakes"
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

var jobFailureServerPort int = 5000

func getJobFailureServerPort() int {
	jobFailureServerPort++
	return jobFailureServerPort
}

func init() {
	Describe("monitJobSupervisor", func() {
		var (
			fs                    *fakesys.FakeFileSystem
			runner                *fakesys.FakeCmdRunner
			client                *fakemonit.FakeMonitClient
			logger                boshlog.Logger
			dirProvider           boshdir.DirectoriesProvider
			jobFailuresServerPort int
			monit                 JobSupervisor
		)

		BeforeEach(func() {
			fs = &fakesys.FakeFileSystem{}
			runner = &fakesys.FakeCmdRunner{}
			client = fakemonit.NewFakeMonitClient()
			logger = boshlog.NewLogger(boshlog.LEVEL_NONE)
			dirProvider = boshdir.NewDirectoriesProvider("/var/vcap")
			jobFailuresServerPort = getJobFailureServerPort()

			monit = NewMonitJobSupervisor(
				fs,
				runner,
				client,
				logger,
				dirProvider,
				jobFailuresServerPort,
				0*time.Millisecond,
			)
		})

		It("waits until the job is reloaded", func() {
			client.Incarnations = []int{1, 1, 1, 2, 3}
			client.StatusStatus = fakemonit.FakeMonitStatus{
				Services: []boshmonit.Service{
					boshmonit.Service{Monitored: true, Status: "failing"},
					boshmonit.Service{Monitored: true, Status: "running"},
				},
				Incarnation: 1,
			}

			err := monit.Reload()

			assert.NoError(GinkgoT(), err)
			assert.Equal(GinkgoT(), 1, len(runner.RunCommands))
			assert.Equal(GinkgoT(), []string{"monit", "reload"}, runner.RunCommands[0])
			assert.Equal(GinkgoT(), client.StatusCalledTimes, 4)
		})

		It("stops trying to reload after 60 attempts", func() {
			for i := 0; i < 61; i++ {
				client.Incarnations = append(client.Incarnations, 1)
			}

			client.StatusStatus = fakemonit.FakeMonitStatus{
				Services: []boshmonit.Service{
					boshmonit.Service{Monitored: true, Status: "failing"},
					boshmonit.Service{Monitored: true, Status: "running"},
				},
				Incarnation: 1,
			}

			err := monit.Reload()

			assert.Error(GinkgoT(), err)
			assert.Equal(GinkgoT(), 1, len(runner.RunCommands))
			assert.Equal(GinkgoT(), []string{"monit", "reload"}, runner.RunCommands[0])
			assert.Equal(GinkgoT(), client.StatusCalledTimes, 60)
		})

		It("start starts each monit service in group vcap", func() {
			client.ServicesInGroupServices = []string{"fake-service"}

			err := monit.Start()
			assert.NoError(GinkgoT(), err)

			assert.Equal(GinkgoT(), "vcap", client.ServicesInGroupName)
			assert.Equal(GinkgoT(), 1, len(client.StartServiceNames))
			assert.Equal(GinkgoT(), "fake-service", client.StartServiceNames[0])
		})

		It("stop stops each monit service in group vcap", func() {
			client.ServicesInGroupServices = []string{"fake-service"}

			err := monit.Stop()
			assert.NoError(GinkgoT(), err)

			assert.Equal(GinkgoT(), "vcap", client.ServicesInGroupName)
			assert.Equal(GinkgoT(), 1, len(client.StopServiceNames))
			assert.Equal(GinkgoT(), "fake-service", client.StopServiceNames[0])
		})

		It("add job", func() {
			fs.WriteFileString("/some/config/path", "some config content")
			monit.AddJob("router", 0, "/some/config/path")

			writtenConfig, err := fs.ReadFileString(dirProvider.MonitJobsDir() + "/0000_router.monitrc")
			assert.NoError(GinkgoT(), err)
			assert.Equal(GinkgoT(), writtenConfig, "some config content")
		})

		It("status returns running when all services are monitored and running", func() {
			client.StatusStatus = fakemonit.FakeMonitStatus{
				Services: []boshmonit.Service{
					boshmonit.Service{Monitored: true, Status: "running"},
					boshmonit.Service{Monitored: true, Status: "running"},
				},
			}

			status := monit.Status()
			assert.Equal(GinkgoT(), "running", status)
		})

		It("status returns failing when all services are monitored and at least one service is failing", func() {
			client.StatusStatus = fakemonit.FakeMonitStatus{
				Services: []boshmonit.Service{
					boshmonit.Service{Monitored: true, Status: "failing"},
					boshmonit.Service{Monitored: true, Status: "running"},
				},
			}

			status := monit.Status()
			assert.Equal(GinkgoT(), "failing", status)
		})

		It("status returns failing when at least one service is not monitored", func() {
			client.StatusStatus = fakemonit.FakeMonitStatus{
				Services: []boshmonit.Service{
					boshmonit.Service{Monitored: false, Status: "running"},
					boshmonit.Service{Monitored: true, Status: "running"},
				},
			}

			status := monit.Status()
			assert.Equal(GinkgoT(), "failing", status)
		})

		It("status returns start when at least one service is starting", func() {
			client.StatusStatus = fakemonit.FakeMonitStatus{
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
			client.StatusErr = errors.New("fake-monit-client-error")

			status := monit.Status()
			assert.Equal(GinkgoT(), "unknown", status)
		})

		It("monitor job failures", func() {
			var handledAlert boshalert.MonitAlert

			failureHandler := func(alert boshalert.MonitAlert) (err error) {
				handledAlert = alert
				return
			}

			go monit.MonitorJobFailures(failureHandler)

			msg := `Message-id: <1304319946.0@localhost>
    Service: nats
    Event: does not exist
    Action: restart
    Date: Sun, 22 May 2011 20:07:41 +0500
    Description: process is not running`

			err := doJobFailureEmail(msg, jobFailuresServerPort)
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

			go monit.MonitorJobFailures(failureHandler)

			msg := `Hi! How'sit goin`

			err := doJobFailureEmail(msg, jobFailuresServerPort)
			assert.NoError(GinkgoT(), err)
			assert.False(GinkgoT(), didHandleAlert)
		})
	})
}
