package monitor

import (
	boshsettings "bosh/settings"
	fakesys "bosh/system/fakes"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestReload(t *testing.T) {
	_, runner, monit := buildMonit()
	err := monit.Reload()

	assert.NoError(t, err)
	assert.Equal(t, 1, len(runner.RunCommands))
	assert.Equal(t, []string{"monit", "reload"}, runner.RunCommands[0])
}

func TestAddJob(t *testing.T) {
	fs, _, monit := buildMonit()
	fs.WriteToFile("/some/config/path", "some config content")
	monit.AddJob("router", 0, "/some/config/path")

	writtenConfig, err := fs.ReadFile(boshsettings.VCAP_MONIT_JOBS_DIR + "/0000_router.monitrc")
	assert.NoError(t, err)
	assert.Equal(t, writtenConfig, "some config content")
}

func buildMonit() (fs *fakesys.FakeFileSystem, runner *fakesys.FakeCmdRunner, monit Monitor) {
	fs = &fakesys.FakeFileSystem{}
	runner = &fakesys.FakeCmdRunner{}
	monit = NewMonit(fs, runner)
	return
}
