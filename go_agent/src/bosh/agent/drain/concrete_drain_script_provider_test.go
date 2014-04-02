package drain_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	. "bosh/agent/drain"
	boshdir "bosh/settings/directories"
	fakesys "bosh/system/fakes"
)

func init() {
	Describe("Testing with Ginkgo", func() {
		It("new drain script", func() {

			runner := fakesys.NewFakeCmdRunner()
			fs := fakesys.NewFakeFileSystem()
			dirProvider := boshdir.NewDirectoriesProvider("/var/vcap")

			scriptProvider := NewConcreteDrainScriptProvider(runner, fs, dirProvider)
			drainScript := scriptProvider.NewDrainScript("foo")

			Expect(drainScript.Path()).To(Equal("/var/vcap/jobs/foo/bin/drain"))
		})
	})
}
