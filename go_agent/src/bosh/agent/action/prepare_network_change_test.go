package action

import (
	fakeplatform "bosh/platform/fakes"
	boshsys "bosh/system"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestPrepareNetworkChangeShouldBeSynchronous(t *testing.T) {
	action, _ := buildPrepareAction()
	assert.False(t, action.IsAsynchronous())
}

func TestPrepareNetworkChange(t *testing.T) {
	action, fs := buildPrepareAction()
	fs.WriteToFile("/etc/udev/rules.d/70-persistent-net.rules", "")

	resp, err := action.Run()

	assert.NoError(t, err)
	assert.Equal(t, "ok", resp)
	assert.False(t, fs.FileExists("/etc/udev/rules.d/70-persistent-net.rules"))
}

func buildPrepareAction() (action prepareNetworkChangeAction, fs boshsys.FileSystem) {
	platform := fakeplatform.NewFakePlatform()
	fs = platform.GetFs()
	action = newPrepareNetworkChange(platform)

	return
}
