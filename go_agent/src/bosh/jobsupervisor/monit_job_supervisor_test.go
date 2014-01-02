package jobsupervisor

import (
	boshmonit "bosh/jobsupervisor/monit"
	fakemonit "bosh/jobsupervisor/monit/fakes"
	boshlog "bosh/logger"
	boshdir "bosh/settings/directories"
	fakesys "bosh/system/fakes"
	"errors"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestReload(t *testing.T) {
	_, runner, _, monit := buildMonitJobSupervisor()
	err := monit.Reload()

	assert.NoError(t, err)
	assert.Equal(t, 1, len(runner.RunCommands))
	assert.Equal(t, []string{"monit", "reload"}, runner.RunCommands[0])
}

func TestStartStartsEachMonitServiceInGroupVcap(t *testing.T) {
	_, _, client, monit := buildMonitJobSupervisor()

	client.ServicesInGroupServices = []string{"fake-service"}

	err := monit.Start()
	assert.NoError(t, err)

	assert.Equal(t, "vcap", client.ServicesInGroupName)
	assert.Equal(t, 1, len(client.StartServiceNames))
	assert.Equal(t, "fake-service", client.StartServiceNames[0])
}

func TestStopStopsEachMonitServiceInGroupVcap(t *testing.T) {
	_, _, client, monit := buildMonitJobSupervisor()

	client.ServicesInGroupServices = []string{"fake-service"}

	err := monit.Stop()
	assert.NoError(t, err)

	assert.Equal(t, "vcap", client.ServicesInGroupName)
	assert.Equal(t, 1, len(client.StopServiceNames))
	assert.Equal(t, "fake-service", client.StopServiceNames[0])
}

func TestAddJob(t *testing.T) {
	fs, _, _, monit := buildMonitJobSupervisor()
	fs.WriteToFile("/some/config/path", "some config content")
	monit.AddJob("router", 0, "/some/config/path")

	writtenConfig, err := fs.ReadFile(monit.dirProvider.MonitJobsDir() + "/0000_router.monitrc")
	assert.NoError(t, err)
	assert.Equal(t, writtenConfig, "some config content")
}

func TestStatusReturnsRunningWhenAllServicesAreMonitoredAndRunning(t *testing.T) {
	_, _, client, monit := buildMonitJobSupervisor()

	client.StatusStatus = &fakemonit.FakeMonitStatus{
		Services: []boshmonit.Service{
			boshmonit.Service{Monitored: true, Status: "running"},
			boshmonit.Service{Monitored: true, Status: "running"},
		},
	}

	status := monit.Status()
	assert.Equal(t, "running", status)
}

func TestStatusReturnsFailingWhenAllServicesAreMonitoredAndAtLeastOneServiceIsFailing(t *testing.T) {
	_, _, client, monit := buildMonitJobSupervisor()

	client.StatusStatus = &fakemonit.FakeMonitStatus{
		Services: []boshmonit.Service{
			boshmonit.Service{Monitored: true, Status: "failing"},
			boshmonit.Service{Monitored: true, Status: "running"},
		},
	}

	status := monit.Status()
	assert.Equal(t, "failing", status)
}

func TestStatusReturnsFailingWhenAtLeastOneServiceIsNotMonitored(t *testing.T) {
	_, _, client, monit := buildMonitJobSupervisor()

	client.StatusStatus = &fakemonit.FakeMonitStatus{
		Services: []boshmonit.Service{
			boshmonit.Service{Monitored: false, Status: "running"},
			boshmonit.Service{Monitored: true, Status: "running"},
		},
	}

	status := monit.Status()
	assert.Equal(t, "failing", status)
}

func TestStatusReturnsStartWhenAtLeastOneServiceIsStarting(t *testing.T) {
	_, _, client, monit := buildMonitJobSupervisor()

	client.StatusStatus = &fakemonit.FakeMonitStatus{
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
	_, _, client, monit := buildMonitJobSupervisor()

	client.StatusErr = errors.New("fake-monit-client-error")

	status := monit.Status()
	assert.Equal(t, "unknown", status)
}

func buildMonitJobSupervisor() (fs *fakesys.FakeFileSystem, runner *fakesys.FakeCmdRunner, client *fakemonit.FakeMonitClient, monit monitJobSupervisor) {
	fs = &fakesys.FakeFileSystem{}
	runner = &fakesys.FakeCmdRunner{}
	client = fakemonit.NewFakeMonitClient()
	logger := boshlog.NewLogger(boshlog.LEVEL_NONE)
	dirProvider := boshdir.NewDirectoriesProvider("/var/vcap")
	monit = NewMonitJobSupervisor(fs, runner, client, logger, dirProvider)
	return
}
