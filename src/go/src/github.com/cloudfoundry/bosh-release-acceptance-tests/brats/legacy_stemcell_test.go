package brats_test

import (
	"fmt"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/ginkgo/extensions/table"
	. "github.com/onsi/gomega"

	"github.com/onsi/gomega/gexec"

	"time"
)

var _ = Describe("Legacy Stemcells", func() {
	BeforeEach(func() {
		startInnerBosh()
	})

	testStemcellDeploy := func(stemcellVersion string) {
		stemcellUrl := fmt.Sprintf(
			"https://s3.amazonaws.com/bosh-core-stemcells/warden/bosh-stemcell-%s-warden-boshlite-ubuntu-trusty-go_agent.tgz",
			stemcellVersion,
		)

		uploadStemcell(stemcellUrl)
		uploadRelease("https://bosh.io/d/github.com/cloudfoundry/os-conf-release?v=12")

		By("Deploying successfully")
		session := bosh("-n", "deploy", assetPath("os-conf-manifest.yml"),
			"-d", "os-conf-deployment",
			"-v", "stemcell-os=ubuntu-trusty",
		)
		Eventually(session, 3*time.Minute).Should(gexec.Exit(0))
	}

	DescribeTable("Stemcells without NATS TLS support", testStemcellDeploy,
		Entry("version 3445", "3445.11"),
	)
})
