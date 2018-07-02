package brats_test

import (
	"time"

	"fmt"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
	"github.com/onsi/gomega/gexec"
)

var _ = Describe("Health Monitor", func() {
	BeforeEach(func() {
		startInnerBosh(
			"-o", assetPath("ops-hm-json-plugin-logger-job.yml"),
			"-v", fmt.Sprintf("hm-json-plugin-release-path=%s", assetPath("hm-json-plugin-release")),
		)
	})

	It("runs JSON plugins", func() {
		session := outerBosh("-d", "bosh", "ssh", "bosh", "-c", "sudo cat /tmp/log-file")
		Eventually(session, time.Minute).Should(gexec.Exit(0))
		Expect(string(session.Out.Contents())).To(ContainSubstring("this only logs if health monitor plugins run"))
	})
})
