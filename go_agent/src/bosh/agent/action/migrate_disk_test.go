package action

import (
	boshassert "bosh/assert"
	fakeplatform "bosh/platform/fakes"
	fakesettings "bosh/settings/fakes"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestMigrateDiskActionRun(t *testing.T) {
	platform, action := buildMigrateDiskAction()

	value, err := action.Run([]byte(""))
	assert.NoError(t, err)
	boshassert.MatchesJsonString(t, value, "{}")

	assert.Equal(t, platform.MigratePersistentDiskFromMountPoint, "/var/vcap/store")
	assert.Equal(t, platform.MigratePersistentDiskToMountPoint, "/var/vcap/store_migration_target")
}

func buildMigrateDiskAction() (platform *fakeplatform.FakePlatform, action migrateDiskAction) {
	platform = fakeplatform.NewFakePlatform()
	settings := &fakesettings.FakeSettingsService{}
	action = newMigrateDisk(settings, platform)
	return
}
