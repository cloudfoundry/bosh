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
			"-o", bratsutils.AssetPath("ops-nginx-enable-metrics.yml"),
		)
	})

	It("returns metrics when curling /stats director nginx endpoint", func() {
		session := bratsutils.OuterBosh("-d", bratsutils.InnerBoshDirectorName(), "ssh", "bosh", "-c", "curl -vk https://127.0.0.1:25555/stats")
		Eventually(session, time.Minute).Should(gexec.Exit(0))
		Expect(string(session.Out.Contents())).To(ContainSubstring("HTTP/1.1 200 OK"))
		Expect(string(session.Out.Contents())).To(ContainSubstring("server accepts handled requests"))
	})

	It("returns metrics when curling /stats bloblstore nginx endpoint", func() {
		session := bratsutils.OuterBosh("-d", bratsutils.InnerBoshDirectorName(), "ssh", "bosh", "-c", "curl -vk https://127.0.0.1:25250/stats")
		Eventually(session, time.Minute).Should(gexec.Exit(0))
		Expect(string(session.Out.Contents())).To(ContainSubstring("HTTP/1.1 200 OK"))
		Expect(string(session.Out.Contents())).To(ContainSubstring("server accepts handled requests"))
	})
})
