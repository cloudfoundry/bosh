package drain

import (
	boshdir "bosh/settings/directories"
	fakesys "bosh/system/fakes"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestNewDrainScript(t *testing.T) {
	runner := fakesys.NewFakeCmdRunner()
	fs := fakesys.NewFakeFileSystem()
	dirProvider := boshdir.NewDirectoriesProvider("/var/vcap")

	scriptProvider := NewConcreteDrainScriptProvider(runner, fs, dirProvider)
	drainScript := scriptProvider.NewDrainScript("foo")

	assert.Equal(t, drainScript.Path(), "/var/vcap/jobs/foo/bin/drain")
}
