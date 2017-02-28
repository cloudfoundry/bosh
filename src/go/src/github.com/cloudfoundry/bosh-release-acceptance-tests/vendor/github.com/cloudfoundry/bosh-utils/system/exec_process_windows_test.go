// +build windows

package system_test

import (
	"fmt"
	"os/exec"
	"time"

	boshlog "github.com/cloudfoundry/bosh-utils/logger"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	. "github.com/cloudfoundry/bosh-utils/system"
)

var _ = Describe("execCmdRunner", func() {
	var logger boshlog.Logger

	BeforeEach(func() {
		logger = boshlog.NewLogger(boshlog.LevelNone)
	})

	Describe("Start", func() {

		It("runs and exits", func() {
			command := exec.Command("cmd.exe", "/C", "dir")
			process := NewExecProcess(command, false, logger)
			err := process.Start()
			Expect(err).ToNot(HaveOccurred())

			result := Result{}
			Eventually(process.Wait()).Should(Receive(&result))
			Expect(result.Error).ToNot(HaveOccurred())
			Expect(result.ExitStatus).To(Equal(0))
		})
	})

	Describe("TerminateNicely", func() {
		Context("when process exists", func() {
			It("kills the process and returns its exit status", func() {
				execProcess := NewExecProcess(exec.Command(WindowsExePath), false, logger)
				err := execProcess.Start()
				Expect(err).ToNot(HaveOccurred())

				waitCh := execProcess.Wait()

				err = execProcess.TerminateNicely(1 * time.Minute)
				Expect(err).ToNot(HaveOccurred())

				var result Result
				select {
				case result = <-waitCh:
					// ok
				case <-time.After(time.Second * 10):
					Fail(fmt.Sprintf("TerminateNicely timed out after: %s", time.Second*10), 1)
				}
				Expect(result.Error).To(HaveOccurred())
				Expect(result.ExitStatus).To(Equal(1))
			})
		})

		Context("when process does not exist", func() {
			It("returns no error", func() {
				execProcess := NewExecProcess(exec.Command(WindowsExePath), false, logger)
				err := execProcess.Start()
				Expect(err).ToNot(HaveOccurred())

				waitCh := execProcess.Wait()

				err = execProcess.TerminateNicely(1 * time.Minute)
				Expect(err).ToNot(HaveOccurred())

				var result Result
				select {
				case result = <-waitCh:
					// ok
				case <-time.After(time.Second * 10):
					Fail(fmt.Sprintf("TerminateNicely timed out after: %s", time.Second*10), 1)
				}
				Expect(result.Error).To(HaveOccurred())
				Expect(result.ExitStatus).To(Equal(1))

				err = execProcess.TerminateNicely(1 * time.Minute)
				Expect(err).ToNot(HaveOccurred())
			})
		})
	})
})
