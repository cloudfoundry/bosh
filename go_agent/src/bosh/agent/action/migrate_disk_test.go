package action_test

import (
	. "bosh/agent/action"
	boshassert "bosh/assert"
	fakeplatform "bosh/platform/fakes"
	boshdirs "bosh/settings/directories"
	. "github.com/onsi/ginkgo"
	"github.com/stretchr/testify/assert"
)

func buildMigrateDiskAction() (platform *fakeplatform.FakePlatform, action MigrateDiskAction) {
	platform = fakeplatform.NewFakePlatform()
	dirProvider := boshdirs.NewDirectoriesProvider("/foo")
	action = NewMigrateDisk(platform, dirProvider)
	return
}
func init() {
	Describe("Testing with Ginkgo", func() {
		It("migrate disk should be asynchronous", func() {
			_, action := buildMigrateDiskAction()
			assert.True(GinkgoT(), action.IsAsynchronous())
		})
		It("migrate disk action run", func() {

			platform, action := buildMigrateDiskAction()

			value, err := action.Run()
			assert.NoError(GinkgoT(), err)
			boshassert.MatchesJsonString(GinkgoT(), value, "{}")

			assert.Equal(GinkgoT(), platform.MigratePersistentDiskFromMountPoint, "/foo/store")
			assert.Equal(GinkgoT(), platform.MigratePersistentDiskToMountPoint, "/foo/store_migration_target")
		})
	})
}
