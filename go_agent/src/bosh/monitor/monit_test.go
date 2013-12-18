package monitor

import (
	boshlog "bosh/logger"
	fakemonit "bosh/monitor/monit/fakes"
	boshsettings "bosh/settings"
	fakesys "bosh/system/fakes"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestReload(t *testing.T) {
	_, runner, _, monit := buildMonit()
	err := monit.Reload()

	assert.NoError(t, err)
	assert.Equal(t, 1, len(runner.RunCommands))
	assert.Equal(t, []string{"monit", "reload"}, runner.RunCommands[0])
}

func TestStartStartsEachMonitServiceInGroupVcap(t *testing.T) {
	_, _, client, monit := buildMonit()

	client.ServicesInGroupServices = []string{"fake-service"}

	err := monit.Start()
	assert.NoError(t, err)

	assert.Equal(t, "vcap", client.ServicesInGroupName)
	assert.Equal(t, 1, len(client.StartServiceNames))
	assert.Equal(t, "fake-service", client.StartServiceNames[0])
}

func TestStopStopsEachMonitServiceInGroupVcap(t *testing.T) {
	_, _, client, monit := buildMonit()

	client.ServicesInGroupServices = []string{"fake-service"}

	err := monit.Stop()
	assert.NoError(t, err)

	assert.Equal(t, "vcap", client.ServicesInGroupName)
	assert.Equal(t, 1, len(client.StopServiceNames))
	assert.Equal(t, "fake-service", client.StopServiceNames[0])
}

func TestAddJob(t *testing.T) {
	fs, _, _, monit := buildMonit()
	fs.WriteToFile("/some/config/path", "some config content")
	monit.AddJob("router", 0, "/some/config/path")

	writtenConfig, err := fs.ReadFile(boshsettings.VCAP_MONIT_JOBS_DIR + "/0000_router.monitrc")
	assert.NoError(t, err)
	assert.Equal(t, writtenConfig, "some config content")
}

func buildMonit() (fs *fakesys.FakeFileSystem, runner *fakesys.FakeCmdRunner, client *fakemonit.FakeMonitClient, monit Monitor) {
	fs = &fakesys.FakeFileSystem{}
	runner = &fakesys.FakeCmdRunner{}
	client = fakemonit.NewFakeMonitClient()
	logger := boshlog.NewLogger(boshlog.LEVEL_NONE)
	monit = NewMonit(fs, runner, client, logger)
	return
}
