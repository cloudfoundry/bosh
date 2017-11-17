package brats_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/ginkgo/extensions/table"

	"time"
)

var _ = Describe("Bosh supporting old stemcells with gnatsd enabled director", func() {
	BeforeEach(func() {
		startInnerBosh()
	})

	AfterEach(func() {
		stopInnerBosh()
	})

	testStemcellDeploy := func(stemcellUrl string) {
		uploadStemcell(stemcellUrl)
		uploadRelease("https://bosh.io/d/github.com/cloudfoundry/os-conf-release?v=12")

		session, err := bosh("-n", "deploy", assetPath("os-conf-manifest.yml"), "-d", "os-conf-deployment")
		mustExec(session, err, 3*time.Minute, 0)
	}

	DescribeTable("creates a deployment with stemcell successfully", testStemcellDeploy,
		Entry("version 3445",
			"https://s3.amazonaws.com/bosh-core-stemcells/warden/bosh-stemcell-3445.11-warden-boshlite-ubuntu-trusty-go_agent.tgz"),
		Entry("version 3431",
			"https://s3.amazonaws.com/bosh-core-stemcells/warden/bosh-stemcell-3431.13-warden-boshlite-ubuntu-trusty-go_agent.tgz"),
		Entry("version 3421",
			"https://s3.amazonaws.com/bosh-core-stemcells/warden/bosh-stemcell-3421.26-warden-boshlite-ubuntu-trusty-go_agent.tgz"),
		Entry("version 3363",
			"https://s3.amazonaws.com/bosh-core-stemcells/warden/bosh-stemcell-3363.37-warden-boshlite-ubuntu-trusty-go_agent.tgz"),
	)
})
