package brats_test

import (
	"io/ioutil"
	"os/exec"
	"path/filepath"
	"time"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
	"github.com/onsi/gomega/gexec"
)

var _ = Describe("logging", func() {
	BeforeEach(func() {
		session, err := gexec.Start(exec.Command("../../../../../../../ci/docker/main-bosh-docker/start-inner-bosh.sh"), GinkgoWriter, GinkgoWriter)
		Expect(err).ToNot(HaveOccurred())
		Eventually(session, 15*time.Minute).Should(gexec.Exit(0))
	})

	AfterEach(func() {
		session, err := gexec.Start(exec.Command("../../../../../../../ci/docker/main-bosh-docker/destroy-inner-bosh.sh"), GinkgoWriter, GinkgoWriter)
		Expect(err).ToNot(HaveOccurred())
		Eventually(session, 10*time.Minute).Should(gexec.Exit(0))
	})

	It("does not log credentials to the debug logs of director and workers", func() {
		configPath, err := filepath.Abs("../assets/cpi-config.yml")
		Expect(err).NotTo(HaveOccurred())

		redactable := "password: c1oudc0w"

		content, err := ioutil.ReadFile(configPath)
		Expect(err).NotTo(HaveOccurred())
		Expect(string(content)).To(ContainSubstring(redactable))

		session, err := gexec.Start(exec.Command(boshBinaryPath, "-n", "update-cpi-config", configPath), GinkgoWriter, GinkgoWriter)
		Expect(err).NotTo(HaveOccurred())
		Eventually(session, 15*time.Second).Should(gexec.Exit(0))

		session, err = gexec.Start(exec.Command(outerBoshBinaryPath, "-d", "bosh", "ssh", "bosh", "-c", "sudo cat /var/vcap/sys/log/director/*"), GinkgoWriter, GinkgoWriter)
		Expect(err).ToNot(HaveOccurred())
		Eventually(session, time.Minute).Should(gexec.Exit(0))
		Expect(string(session.Out.Contents())).NotTo(ContainSubstring(redactable))
		Expect(string(session.Out.Contents())).NotTo(ContainSubstring("SELECT NULL"))
	})
})
