package brats_test

import (
	"time"

	"fmt"

	bratsutils "github.com/cloudfoundry/bosh-release-acceptance-tests/brats-utils"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
	"github.com/onsi/gomega/gexec"
)

var _ = Describe("Health Monitor", func() {
	BeforeEach(func() {
		bratsutils.StartInnerBosh(
			"-o", bratsutils.AssetPath("ops-hm-json-plugin-logger-job.yml"),
			"-v", fmt.Sprintf("hm-json-plugin-release-path=%s", bratsutils.AssetPath("hm-json-plugin-release")),
		)
	})

	It("runs JSON plugins", func() {
		session := bratsutils.OuterBosh("-d", bratsutils.InnerBoshDirectorName(), "ssh", "bosh", "-c", "sudo /var/vcap/packages/bpm/bin/runc --root /var/vcap/sys/run/bpm-runc exec bpm-health_monitor cat /tmp/log-file")
		Eventually(session, 2*time.Minute).Should(gexec.Exit(0))
		Expect(string(session.Out.Contents())).To(ContainSubstring("this only logs if health monitor plugins run"))
	})
})
