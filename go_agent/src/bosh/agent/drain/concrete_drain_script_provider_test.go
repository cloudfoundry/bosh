package drain_test

import (
	. "bosh/agent/drain"
	boshdir "bosh/settings/directories"
	fakesys "bosh/system/fakes"
	. "github.com/onsi/ginkgo"
	"github.com/stretchr/testify/assert"
)

func init() {
	Describe("Testing with Ginkgo", func() {
		It("new drain script", func() {

			runner := fakesys.NewFakeCmdRunner()
			fs := fakesys.NewFakeFileSystem()
			dirProvider := boshdir.NewDirectoriesProvider("/var/vcap")

			scriptProvider := NewConcreteDrainScriptProvider(runner, fs, dirProvider)
			drainScript := scriptProvider.NewDrainScript("foo")

			assert.Equal(GinkgoT(), drainScript.Path(), "/var/vcap/jobs/foo/bin/drain")
		})
	})
}
