package brats_test

import (
	"fmt"
	"io/ioutil"
	"time"

	bratsutils "github.com/cloudfoundry/bosh-release-acceptance-tests/brats-utils"
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
	"github.com/onsi/gomega/gexec"
)

var _ = Describe("nginx with ngx_http_stub_status_module compiled", func() {
	BeforeEach(func() {
		bratsutils.StartInnerBosh(
			"-o", bratsutils.AssetPath("ops-enable-metrics.yml"),
			"-o", bratsutils.BoshDeploymentAssetPath("experimental/enable-metrics.yml"),
		)
	})

	It("returns metrics when curling metrics endpoints for nginx, blobstore, and nats", func() {
		session := bratsutils.OuterBosh("-d", bratsutils.InnerBoshDirectorName(), "ssh", "bosh", "-c", "curl -vk https://127.0.0.1:25555/stats")
		Eventually(session, time.Minute).Should(gexec.Exit(0))
		Expect(string(session.Out.Contents())).To(ContainSubstring("HTTP/1.1 200 OK"))
		Expect(string(session.Out.Contents())).To(ContainSubstring("server accepts handled requests"))

		session = bratsutils.OuterBosh("-d", bratsutils.InnerBoshDirectorName(), "ssh", "bosh", "-c", "curl -vk https://127.0.0.1:25250/stats")
		Eventually(session, time.Minute).Should(gexec.Exit(0))
		Expect(string(session.Out.Contents())).To(ContainSubstring("HTTP/1.1 200 OK"))
		Expect(string(session.Out.Contents())).To(ContainSubstring("server accepts handled requests"))

		session = bratsutils.OuterBosh("-d", bratsutils.InnerBoshDirectorName(), "ssh", "bosh", "-c", "curl -v http://localhost:8222")
		Eventually(session, time.Minute).Should(gexec.Exit(0))
		Expect(string(session.Out.Contents())).To(ContainSubstring("HTTP/1.1 200 OK"))

		metricsClient := bratsutils.MetricsServerHTTPClient()
		resp, err := metricsClient.Get(fmt.Sprintf("https://%s:9091/metrics", bratsutils.InnerDirectorIP()))
		Expect(err).NotTo(HaveOccurred())
		defer resp.Body.Close()

		contents, err := ioutil.ReadAll(resp.Body)
		Expect(err).NotTo(HaveOccurred())
		Expect(string(contents)).To(ContainSubstring("processing_tasks"))
		Expect(string(contents)).To(ContainSubstring("queued_tasks"))

		api_metrics_resp, err := metricsClient.Get(fmt.Sprintf("https://%s:9091/api_metrics", bratsutils.InnerDirectorIP()))
		Expect(err).NotTo(HaveOccurred())
		defer api_metrics_resp.Body.Close()

		contents, err = ioutil.ReadAll(api_metrics_resp.Body)
		Expect(err).NotTo(HaveOccurred())
		Expect(string(contents)).To(ContainSubstring("http_server_requests_total"))
		Expect(string(contents)).To(ContainSubstring("http_server_request_duration_seconds"))
	})
})
