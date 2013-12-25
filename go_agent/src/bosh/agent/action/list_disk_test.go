package action

import (
	boshassert "bosh/assert"
	fakeplatform "bosh/platform/fakes"
	boshsettings "bosh/settings"
	fakesettings "bosh/settings/fakes"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestListDiskShouldBeSynchronous(t *testing.T) {
	settings := &fakesettings.FakeSettingsService{}
	platform := fakeplatform.NewFakePlatform()
	action := newListDisk(settings, platform)
	assert.False(t, action.IsAsynchronous())
}

func TestListDiskRun(t *testing.T) {
	settings := &fakesettings.FakeSettingsService{
		Disks: boshsettings.Disks{
			Persistent: map[string]string{
				"volume-1": "/dev/sda",
				"volume-2": "/dev/sdb",
				"volume-3": "/dev/sdc",
			},
		},
	}
	platform := fakeplatform.NewFakePlatform()
	platform.MountedDevicePaths = []string{"/dev/sdb", "/dev/sdc"}

	action := newListDisk(settings, platform)
	value, err := action.Run()
	assert.NoError(t, err)
	boshassert.MatchesJsonString(t, value, `["volume-2","volume-3"]`)
}
