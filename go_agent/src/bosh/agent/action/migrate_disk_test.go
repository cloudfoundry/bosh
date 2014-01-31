package action

import (
	boshassert "bosh/assert"
	fakeplatform "bosh/platform/fakes"
	boshdirs "bosh/settings/directories"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestMigrateDiskShouldBeAsynchronous(t *testing.T) {
	_, action := buildMigrateDiskAction()
	assert.True(t, action.IsAsynchronous())
}

func TestMigrateDiskActionRun(t *testing.T) {
	platform, action := buildMigrateDiskAction()

	value, err := action.Run()
	assert.NoError(t, err)
	boshassert.MatchesJsonString(t, value, "{}")

	assert.Equal(t, platform.MigratePersistentDiskFromMountPoint, "/foo/store")
	assert.Equal(t, platform.MigratePersistentDiskToMountPoint, "/foo/store_migration_target")
}

func buildMigrateDiskAction() (platform *fakeplatform.FakePlatform, action migrateDiskAction) {
	platform = fakeplatform.NewFakePlatform()
	dirProvider := boshdirs.NewDirectoriesProvider("/foo")
	action = newMigrateDisk(platform, dirProvider)
	return
}
