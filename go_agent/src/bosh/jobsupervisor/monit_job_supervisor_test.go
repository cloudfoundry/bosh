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

var jobFailureServerPort = 5000

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
			fs = fakesys.NewFakeFileSystem()
			runner = fakesys.NewFakeCmdRunner()
			client = fakemonit.NewFakeMonitClient()
			logger = boshlog.NewLogger(boshlog.LevelNone)
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

			Expect(err).ToNot(HaveOccurred())
			Expect(1).To(Equal(len(runner.RunCommands)))
			Expect(runner.RunCommands[0]).To(Equal([]string{"monit", "reload"}))
			Expect(client.StatusCalledTimes).To(Equal(4))
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

			Expect(err).To(HaveOccurred())
			Expect(1).To(Equal(len(runner.RunCommands)))
			Expect(runner.RunCommands[0]).To(Equal([]string{"monit", "reload"}))
			Expect(client.StatusCalledTimes).To(Equal(60))
		})

		It("start starts each monit service in group vcap", func() {
			client.ServicesInGroupServices = []string{"fake-service"}

			err := monit.Start()
			Expect(err).ToNot(HaveOccurred())

			Expect("vcap").To(Equal(client.ServicesInGroupName))
			Expect(1).To(Equal(len(client.StartServiceNames)))
			Expect("fake-service").To(Equal(client.StartServiceNames[0]))
		})

		It("stop stops each monit service in group vcap", func() {
			client.ServicesInGroupServices = []string{"fake-service"}

			err := monit.Stop()
			Expect(err).ToNot(HaveOccurred())

			Expect("vcap").To(Equal(client.ServicesInGroupName))
			Expect(1).To(Equal(len(client.StopServiceNames)))
			Expect("fake-service").To(Equal(client.StopServiceNames[0]))
		})

		It("status returns running when all services are monitored and running", func() {
			client.StatusStatus = fakemonit.FakeMonitStatus{
				Services: []boshmonit.Service{
					boshmonit.Service{Monitored: true, Status: "running"},
					boshmonit.Service{Monitored: true, Status: "running"},
				},
			}

			status := monit.Status()
			Expect("running").To(Equal(status))
		})

		It("status returns failing when all services are monitored and at least one service is failing", func() {
			client.StatusStatus = fakemonit.FakeMonitStatus{
				Services: []boshmonit.Service{
					boshmonit.Service{Monitored: true, Status: "failing"},
					boshmonit.Service{Monitored: true, Status: "running"},
				},
			}

			status := monit.Status()
			Expect("failing").To(Equal(status))
		})

		It("status returns failing when at least one service is not monitored", func() {
			client.StatusStatus = fakemonit.FakeMonitStatus{
				Services: []boshmonit.Service{
					boshmonit.Service{Monitored: false, Status: "running"},
					boshmonit.Service{Monitored: true, Status: "running"},
				},
			}

			status := monit.Status()
			Expect("failing").To(Equal(status))
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
			Expect("starting").To(Equal(status))
		})

		It("status returns unknown when error", func() {
			client.StatusErr = errors.New("fake-monit-client-error")

			status := monit.Status()
			Expect("unknown").To(Equal(status))
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
			Expect(err).ToNot(HaveOccurred())

			assert.Equal(GinkgoT(), handledAlert, boshalert.MonitAlert{
				ID:          "1304319946.0@localhost",
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
			Expect(err).ToNot(HaveOccurred())
			Expect(didHandleAlert).To(BeFalse())
		})

		Describe("AddJob", func() {
			BeforeEach(func() {
				fs.WriteFileString("/some/config/path", "fake-config")
			})

			Context("when reading configuration from config path succeeds", func() {
				Context("when writing job configuration succeeds", func() {
					It("returns no error because monit can track added job in jobs directory", func() {
						err := monit.AddJob("router", 0, "/some/config/path")
						Expect(err).ToNot(HaveOccurred())

						writtenConfig, err := fs.ReadFileString(
							dirProvider.MonitJobsDir() + "/0000_router.monitrc")
						Expect(err).ToNot(HaveOccurred())
						Expect(writtenConfig).To(Equal("fake-config"))
					})
				})

				Context("when writing job configuration fails", func() {
					It("returns error", func() {
						fs.WriteToFileError = errors.New("fake-write-error")

						err := monit.AddJob("router", 0, "/some/config/path")
						Expect(err).To(HaveOccurred())
						Expect(err.Error()).To(ContainSubstring("fake-write-error"))
					})
				})
			})

			Context("when reading configuration from config path fails", func() {
				It("returns error", func() {
					fs.ReadFileError = errors.New("fake-read-error")

					err := monit.AddJob("router", 0, "/some/config/path")
					Expect(err).To(HaveOccurred())
					Expect(err.Error()).To(ContainSubstring("fake-read-error"))
				})
			})
		})

		Describe("RemoveAllJobs", func() {
			Context("when jobs directory removal succeeds", func() {
				It("does not return error because all jobs are removed from monit", func() {
					jobsDir := dirProvider.MonitJobsDir()
					jobBasename := "/0000_router.monitrc"
					fs.WriteFileString(jobsDir+jobBasename, "fake-added-job")

					err := monit.RemoveAllJobs()
					Expect(err).ToNot(HaveOccurred())

					Expect(fs.FileExists(jobsDir)).To(BeFalse())
					Expect(fs.FileExists(jobsDir + jobBasename)).To(BeFalse())
				})
			})

			Context("when jobs directory removal fails", func() {
				It("returns error if removing jobs directory fails", func() {
					fs.RemoveAllError = errors.New("fake-remove-all-error")

					err := monit.RemoveAllJobs()
					Expect(err).To(HaveOccurred())
					Expect(err.Error()).To(ContainSubstring("fake-remove-all-error"))
				})
			})
		})

		Describe("Unmonitor", func() {
			BeforeEach(func() {
				client.ServicesInGroupServices = []string{"fake-srv-1", "fake-srv-2", "fake-srv-3"}
				client.UnmonitorServiceErrs = []error{nil, nil, nil}
			})

			Context("when all services succeed to be unmonitored", func() {
				It("returns no error because all services got unmonitored", func() {
					err := monit.Unmonitor()
					Expect(err).ToNot(HaveOccurred())

					Expect(client.ServicesInGroupName).To(Equal("vcap"))
					Expect(client.UnmonitorServiceNames).To(Equal(
						[]string{"fake-srv-1", "fake-srv-2", "fake-srv-3"}))
				})
			})

			Context("when at least one service fails to be unmonitored", func() {
				BeforeEach(func() {
					client.UnmonitorServiceErrs = []error{
						nil, errors.New("fake-unmonitor-error"), nil,
					}
				})

				It("returns first unmonitor error", func() {
					err := monit.Unmonitor()
					Expect(err).To(HaveOccurred())
					Expect(err.Error()).To(ContainSubstring("fake-unmonitor-error"))
				})

				It("only tries to unmonitor services before the first unmonitor error", func() {
					err := monit.Unmonitor()
					Expect(err).To(HaveOccurred())
					Expect(client.ServicesInGroupName).To(Equal("vcap"))
					Expect(client.UnmonitorServiceNames).To(Equal([]string{"fake-srv-1", "fake-srv-2"}))
				})
			})

			Context("when failed retrieving list of services", func() {
				It("returns error", func() {
					client.ServicesInGroupErr = errors.New("fake-services-error")

					err := monit.Unmonitor()
					Expect(err).To(HaveOccurred())
					Expect(err.Error()).To(ContainSubstring("fake-services-error"))
				})
			})
		})
	})
}
