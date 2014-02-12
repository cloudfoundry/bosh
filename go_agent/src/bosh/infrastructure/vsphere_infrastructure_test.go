package infrastructure_test

import (
	. "bosh/infrastructure"
	fakeplatform "bosh/platform/fakes"
	boshsettings "bosh/settings"
	. "github.com/onsi/ginkgo"
	"github.com/stretchr/testify/assert"
)

func buildVsphere() (vsphere Infrastructure, platform *fakeplatform.FakePlatform) {
	platform = fakeplatform.NewFakePlatform()
	vsphere = NewVsphereInfrastructure(platform)
	return
}
func init() {
	Describe("Testing with Ginkgo", func() {
		It("vsphere get settings", func() {
			vsphere, platform := buildVsphere()

			platform.GetFileContentsFromCDROMContents = []byte(`{"agent_id": "123"}`)

			settings, err := vsphere.GetSettings()

			assert.NoError(GinkgoT(), err)
			assert.Equal(GinkgoT(), platform.GetFileContentsFromCDROMPath, "env")
			assert.Equal(GinkgoT(), settings.AgentId, "123")
		})
		It("vsphere setup networking", func() {

			vsphere, platform := buildVsphere()
			networks := boshsettings.Networks{"bosh": boshsettings.Network{}}

			vsphere.SetupNetworking(networks)

			assert.Equal(GinkgoT(), platform.SetupManualNetworkingNetworks, networks)
		})
		It("vsphere get ephemeral disk path", func() {

			vsphere, platform := buildVsphere()

			platform.NormalizeDiskPathRealPath = "/dev/sdb"
			platform.NormalizeDiskPathFound = true

			realPath, found := vsphere.GetEphemeralDiskPath("does not matter")
			assert.True(GinkgoT(), found)
			assert.Equal(GinkgoT(), realPath, "/dev/sdb")
			assert.Equal(GinkgoT(), platform.NormalizeDiskPathPath, "/dev/sdb")
		})
	})
}
