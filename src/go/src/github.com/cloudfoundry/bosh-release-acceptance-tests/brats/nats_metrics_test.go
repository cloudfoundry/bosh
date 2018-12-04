package brats_test

import (
	"time"

	bratsutils "github.com/cloudfoundry/bosh-release-acceptance-tests/brats-utils"
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
	"github.com/onsi/gomega/gexec"
)

var _ = Describe("nginx with ngx_http_stub_status_module compiled", func() {
	BeforeEach(func() {
		bratsutils.StartInnerBosh(
			"-o", bratsutils.AssetPath("ops-nats-enable-metrics.yml"),
		)
	})

	FIt("returns metrics when curling nats monitoring endpoint", func() {
		session := bratsutils.OuterBosh("-d", bratsutils.InnerBoshDirectorName(), "ssh", "bosh", "-c", "curl -v http://localhost:8222")
		Eventually(session, time.Minute).Should(gexec.Exit(0))
		Expect(string(session.Out.Contents())).To(ContainSubstring("HTTP/1.1 200 OK"))
	})
})
