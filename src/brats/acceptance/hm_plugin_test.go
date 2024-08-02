package acceptance_test

import (
	"fmt"
	"time"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
	"github.com/onsi/gomega/gexec"

	"brats/utils"
)

var _ = Describe("Health Monitor", func() {
	BeforeEach(func() {
		utils.StartInnerBosh(
			"-o", utils.AssetPath("ops-hm-json-plugin-logger-job.yml"),
			"-v", fmt.Sprintf("hm-json-plugin-release-path=%s", utils.AssetPath("hm-json-plugin-release")),
		)
	})

	It("runs JSON plugins", func() {
		session := utils.OuterBosh("-d", utils.InnerBoshDirectorName(), "ssh", "bosh", "-c", "sudo /var/vcap/packages/bpm/bin/runc --root /var/vcap/sys/run/bpm-runc exec bpm-health_monitor cat /tmp/log-file")
		Eventually(session, 2*time.Minute).Should(gexec.Exit(0))
		Expect(string(session.Out.Contents())).To(ContainSubstring("this only logs if health monitor plugins run"))
	})
})
