package brats_test

import (
	"io/ioutil"
	"time"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
	"github.com/onsi/gomega/gexec"
)

var _ = Describe("logging", func() {
	BeforeEach(func() {
		startInnerBosh()
	})

	AfterEach(func() {
		stopInnerBosh()
	})

	It("does not log credentials to the debug logs of director and workers", func() {
		configPath := assetPath("cpi-config.yml")
		redactable := "password: c1oudc0w"

		content, err := ioutil.ReadFile(configPath)
		Expect(err).NotTo(HaveOccurred())
		Expect(string(content)).To(ContainSubstring(redactable))

		session := execCommand(boshBinaryPath, "-n", "update-cpi-config", configPath)
		Eventually(session, 15*time.Second).Should(gexec.Exit(0))

		session = outerBosh("-d", "bosh", "ssh", "bosh", "-c", "sudo cat /var/vcap/sys/log/director/*")
		Eventually(session, time.Minute).Should(gexec.Exit(0))
		Expect(string(session.Out.Contents())).To(ContainSubstring("INSERT INTO \"configs\" <redacted>"))
		Expect(string(session.Out.Contents())).NotTo(ContainSubstring(redactable))
		Expect(string(session.Out.Contents())).NotTo(ContainSubstring("SELECT NULL"))
	})
})
