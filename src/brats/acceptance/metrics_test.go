package acceptance_test

import (
	"fmt"
	"io"
	"time"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
	"github.com/onsi/gomega/gexec"

	"brats/utils"
)

var _ = Describe("nginx with ngx_http_stub_status_module compiled", func() {
	BeforeEach(func() {
		utils.StartInnerBosh(
			"-o", utils.AssetPath("ops-enable-metrics.yml"),
			"-o", utils.BoshDeploymentAssetPath("experimental/enable-metrics.yml"),
		)
	})

	It("returns metrics when curling metrics endpoints for nginx, blobstore, and nats", func() {
		session := utils.OuterBosh("-d", utils.InnerBoshDirectorName(), "ssh", "bosh", "-c", "curl -vk https://127.0.0.1:25555/stats")
		Eventually(session, time.Minute).Should(gexec.Exit(0))
		Expect(string(session.Out.Contents())).To(ContainSubstring("HTTP/1.1 200 OK"))
		Expect(string(session.Out.Contents())).To(ContainSubstring("server accepts handled requests"))

		session = utils.OuterBosh("-d", utils.InnerBoshDirectorName(), "ssh", "bosh", "-c", "curl -vk https://127.0.0.1:25250/stats")
		Eventually(session, time.Minute).Should(gexec.Exit(0))
		Expect(string(session.Out.Contents())).To(ContainSubstring("HTTP/1.1 200 OK"))
		Expect(string(session.Out.Contents())).To(ContainSubstring("server accepts handled requests"))

		session = utils.OuterBosh("-d", utils.InnerBoshDirectorName(), "ssh", "bosh", "-c", "curl -v http://localhost:8222")
		Eventually(session, time.Minute).Should(gexec.Exit(0))
		Expect(string(session.Out.Contents())).To(ContainSubstring("HTTP/1.1 200 OK"))

		metricsClient := utils.MetricsServerHTTPClient()
		resp, err := metricsClient.Get(fmt.Sprintf("https://%s:9091/metrics", utils.InnerDirectorIP()))
		Expect(err).NotTo(HaveOccurred())
		defer resp.Body.Close() //nolint:errcheck

		contents, err := io.ReadAll(resp.Body)
		Expect(err).NotTo(HaveOccurred())
		Expect(string(contents)).To(ContainSubstring("bosh_resurrection_enabled"))
		Expect(string(contents)).To(ContainSubstring("bosh_tasks_total"))
		Expect(string(contents)).To(ContainSubstring("bosh_networks_dynamic_ips_total"))
		Expect(string(contents)).To(ContainSubstring("bosh_networks_dynamic_free_ips_total"))

		apiMetricsResp, err := metricsClient.Get(fmt.Sprintf("https://%s:9091/api_metrics", utils.InnerDirectorIP()))
		Expect(err).NotTo(HaveOccurred())
		defer apiMetricsResp.Body.Close() //nolint:errcheck

		contents, err = io.ReadAll(apiMetricsResp.Body)
		Expect(err).NotTo(HaveOccurred())
		Expect(string(contents)).To(ContainSubstring("http_server_requests_total"))
		Expect(string(contents)).To(ContainSubstring("http_server_request_duration_seconds"))
	})
})
