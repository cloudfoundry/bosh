package acceptance_test

import (
	"fmt"
	"os"
	"time"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
	"github.com/onsi/gomega/gexec"

	"brats/utils"
)

var _ = Describe("logging", func() {
	var cpiConfigName string

	BeforeEach(func() {
		cpiConfigName = fmt.Sprintf("%s-logging-test-fake-cpi-config-%d", time.Now().Format("2006-01-02"), GinkgoParallelProcess())
		utils.StartInnerBosh()
	})

	AfterEach(func() {
		session := utils.Bosh("-n", "delete-config", "--type", "cpi", "--name", cpiConfigName)
		Eventually(session, 15*time.Second).Should(gexec.Exit(0))
	})

	It("does not log credentials to the debug logs of director and workers", func() {
		configPath := utils.AssetPath("cpi-config.yml")
		redactable := "password: c1oudc0w"

		content, err := os.ReadFile(configPath)
		Expect(err).NotTo(HaveOccurred())
		Expect(string(content)).To(ContainSubstring(redactable))

		session := utils.Bosh("-n", "update-config", "--type", "cpi", "--name", cpiConfigName, configPath)
		Eventually(session, 1*time.Minute).Should(gexec.Exit(0))

		session = utils.OuterBoshQuiet("-d", utils.InnerBoshDirectorName(), "ssh", "bosh", "-c", "sudo cat /var/vcap/sys/log/director/*")
		Eventually(session, 2*time.Minute).Should(gexec.Exit(0))
		Expect(string(session.Out.Contents())).To(ContainSubstring(`INSERT INTO "configs" <redacted>`))
		Expect(string(session.Out.Contents())).NotTo(ContainSubstring(redactable))
	})
})
