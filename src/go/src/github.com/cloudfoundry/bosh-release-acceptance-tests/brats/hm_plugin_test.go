package brats_test

import (
	"time"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
	"github.com/onsi/gomega/gexec"
	"fmt"
)

var _ = Describe("Health Monitor", func() {
	BeforeEach(func() {
		releaseTarballPath := releaseTarball(assetPath("hm-json-plugin-release"))
		startInnerBosh(
			"-o", assetPath("ops-hm-json-plugin-logger-job.yml"),
			"-v", fmt.Sprintf("hm-json-plugin-release-tarball=%s", releaseTarballPath),
			)
	})

	AfterEach(func() {
		stopInnerBosh()
	})

	It("runs JSON plugins", func() {
		session := outerBosh("-d", "bosh", "ssh", "bosh", "-c", "sudo cat /tmp/log-file")
		Eventually(session, time.Minute).Should(gexec.Exit(0))
		Expect(string(session.Out.Contents())).To(ContainSubstring("this only logs if health monitor plugins run"))
	})
})
