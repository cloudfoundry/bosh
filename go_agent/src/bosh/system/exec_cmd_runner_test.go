package system_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
	"github.com/stretchr/testify/assert"

	boshlog "bosh/logger"
	. "bosh/system"
)

func createRunner() (r CmdRunner) {
	r = NewExecCmdRunner(boshlog.NewLogger(boshlog.LevelNone))
	return
}
func init() {
	Describe("Testing with Ginkgo", func() {
		It("run complex command with working directory", func() {
			cmd := Command{
				Name:       "ls",
				Args:       []string{"-l"},
				WorkingDir: "../../..",
			}
			runner := createRunner()
			stdout, stderr, err := runner.RunComplexCommand(cmd)
			Expect(err).ToNot(HaveOccurred())
			assert.Empty(GinkgoT(), stderr)
			assert.Contains(GinkgoT(), stdout, "README.md")
			assert.Contains(GinkgoT(), stdout, "total")
		})

		It("run complex command with env", func() {
			cmd := Command{
				Name: "env",
				Env: map[string]string{
					"FOO": "BAR",
				},
			}
			runner := createRunner()
			stdout, stderr, err := runner.RunComplexCommand(cmd)
			Expect(err).ToNot(HaveOccurred())
			assert.Empty(GinkgoT(), stderr)
			assert.Contains(GinkgoT(), stdout, "FOO=BAR")
			assert.Contains(GinkgoT(), stdout, "PATH=")
		})

		It("run command", func() {
			runner := createRunner()
			stdout, stderr, err := runner.RunCommand("echo", "Hello World!")
			Expect(err).ToNot(HaveOccurred())
			assert.Empty(GinkgoT(), stderr)
			Expect(stdout).To(Equal("Hello World!\n"))
		})

		It("run command with error output", func() {
			runner := createRunner()
			stdout, stderr, err := runner.RunCommand("sh", "-c", "echo error-output >&2")
			Expect(err).ToNot(HaveOccurred())
			assert.Contains(GinkgoT(), stderr, "error-output")
			assert.Empty(GinkgoT(), stdout)
		})

		It("run command with error", func() {
			runner := createRunner()
			stdout, stderr, err := runner.RunCommand("false")
			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(Equal("Running command: 'false', stdout: '', stderr: '': exit status 1"))
			assert.Empty(GinkgoT(), stderr)
			assert.Empty(GinkgoT(), stdout)
		})

		It("run command with error with args", func() {
			runner := createRunner()
			stdout, stderr, err := runner.RunCommand("false", "second arg")
			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(Equal("Running command: 'false second arg', stdout: '', stderr: '': exit status 1"))
			assert.Empty(GinkgoT(), stderr)
			assert.Empty(GinkgoT(), stdout)
		})

		It("run command with cmd not found", func() {
			runner := createRunner()
			stdout, stderr, err := runner.RunCommand("something that does not exist")
			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(ContainSubstring("not found"))
			assert.Empty(GinkgoT(), stderr)
			assert.Empty(GinkgoT(), stdout)
		})

		It("run command with input", func() {
			runner := createRunner()
			stdout, stderr, err := runner.RunCommandWithInput("foo\nbar\nbaz", "grep", "ba")
			Expect(err).ToNot(HaveOccurred())
			Expect("bar\nbaz\n").To(Equal(stdout))
			assert.Empty(GinkgoT(), stderr)
		})

		It("command exists", func() {
			runner := createRunner()
			Expect(runner.CommandExists("env")).To(BeTrue())
			Expect(runner.CommandExists("absolutely-does-not-exist-ever-please-unicorns")).To(BeFalse())
		})
	})
}
