package acceptance_test

import (
	"os/exec"
	"syscall"
	"time"

	"github.com/creack/pty"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
	"github.com/onsi/gomega/gbytes"
	"github.com/onsi/gomega/gexec"

	"brats/utils"
)

var _ = Describe("director console", func() {
	BeforeEach(func() {
		utils.StartInnerBosh()
	})

	It("allows a user to launch the director console", func() {
		ptyF, ttyF, err := pty.Open()
		Expect(err).ShouldNot(HaveOccurred())
		defer ptyF.Close() //nolint:errcheck

		consoleCmd := exec.Command(utils.OuterBoshBinaryPath(), "-d", utils.InnerBoshDirectorName(), "ssh", "bosh")
		consoleCmd.Stdin = ttyF
		consoleCmd.Stdout = ttyF
		consoleCmd.Stderr = ttyF
		consoleCmd.SysProcAttr = &syscall.SysProcAttr{Setctty: true, Setsid: true}

		session, err := gexec.Start(consoleCmd, GinkgoWriter, GinkgoWriter)
		Expect(err).ShouldNot(HaveOccurred())
		Expect(ttyF.Close()).To(Succeed())

		Eventually(session.Out, 1*time.Minute).Should(gbytes.Say(`bosh/[0-9a-f\-]{36}:~\$ `))

		_, err = ptyF.Write([]byte("sudo su -\n"))
		Expect(err).NotTo(HaveOccurred())

		Eventually(session.Out, 1*time.Minute).Should(gbytes.Say(`bosh/[0-9a-f\-]{36}:~\# `))

		_, err = ptyF.Write([]byte("echo 'IRB.conf[:USE_COLORIZE] = false' > ~/.irbrc\n"))
		Expect(err).NotTo(HaveOccurred())

		_, err = ptyF.Write([]byte("echo 'Bosh::Director::VERSION' | /var/vcap/jobs/director/bin/console\n"))
		Expect(err).NotTo(HaveOccurred())

		Eventually(session.Out, 1*time.Minute).Should(gbytes.Say(`"0.0.0"`))

		_, err = ptyF.Write([]byte("exit\n"))
		Expect(err).NotTo(HaveOccurred())
		Eventually(session.Out, 1*time.Minute).Should(gbytes.Say(`bosh/[0-9a-f\-]{36}:~\$ `))

		_, err = ptyF.Write([]byte("exit\n"))
		Expect(err).NotTo(HaveOccurred())

		Eventually(session, time.Minute).Should(gexec.Exit(0))
	})
})
