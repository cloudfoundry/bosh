package system_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

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
			stdout, stderr, status, err := runner.RunComplexCommand(cmd)
			Expect(err).ToNot(HaveOccurred())
			Expect(stdout).To(ContainSubstring("README.md"))
			Expect(stdout).To(ContainSubstring("total"))
			Expect(stderr).To(BeEmpty())
			Expect(status).To(Equal(0))
		})

		It("run complex command with env", func() {
			cmd := Command{
				Name: "env",
				Env: map[string]string{
					"FOO": "BAR",
				},
			}
			runner := createRunner()
			stdout, stderr, status, err := runner.RunComplexCommand(cmd)
			Expect(err).ToNot(HaveOccurred())
			Expect(stdout).To(ContainSubstring("FOO=BAR"))
			Expect(stdout).To(ContainSubstring("PATH="))
			Expect(stderr).To(BeEmpty())
			Expect(status).To(Equal(0))
		})

		It("run command", func() {
			runner := createRunner()
			stdout, stderr, status, err := runner.RunCommand("echo", "Hello World!")
			Expect(err).ToNot(HaveOccurred())
			Expect(stdout).To(Equal("Hello World!\n"))
			Expect(stderr).To(BeEmpty())
			Expect(status).To(Equal(0))
		})

		It("run command with error output", func() {
			runner := createRunner()
			stdout, stderr, status, err := runner.RunCommand("sh", "-c", "echo error-output >&2")
			Expect(err).ToNot(HaveOccurred())
			Expect(stdout).To(BeEmpty())
			Expect(stderr).To(ContainSubstring("error-output"))
			Expect(status).To(Equal(0))
		})

		It("run command with non-0 exit status", func() {
			runner := createRunner()
			stdout, stderr, status, err := runner.RunCommand("sh", "-c", "exit 14")
			Expect(err).To(HaveOccurred())
			Expect(stdout).To(BeEmpty())
			Expect(stderr).To(BeEmpty())
			Expect(status).To(Equal(14))
		})

		It("run command with error", func() {
			runner := createRunner()
			stdout, stderr, status, err := runner.RunCommand("false")
			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(Equal("Running command: 'false', stdout: '', stderr: '': exit status 1"))
			Expect(stderr).To(BeEmpty())
			Expect(stdout).To(BeEmpty())
			Expect(status).To(Equal(1))
		})

		It("run command with error with args", func() {
			runner := createRunner()
			stdout, stderr, status, err := runner.RunCommand("false", "second arg")
			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(Equal("Running command: 'false second arg', stdout: '', stderr: '': exit status 1"))
			Expect(stderr).To(BeEmpty())
			Expect(stdout).To(BeEmpty())
			Expect(status).To(Equal(1))
		})

		It("run command with cmd not found", func() {
			runner := createRunner()
			stdout, stderr, status, err := runner.RunCommand("something that does not exist")
			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(ContainSubstring("not found"))
			Expect(stderr).To(BeEmpty())
			Expect(stdout).To(BeEmpty())
			Expect(status).To(Equal(-1))
		})

		It("run command with input", func() {
			runner := createRunner()
			stdout, stderr, status, err := runner.RunCommandWithInput("foo\nbar\nbaz", "grep", "ba")
			Expect(err).ToNot(HaveOccurred())
			Expect(stdout).To(Equal("bar\nbaz\n"))
			Expect(stderr).To(BeEmpty())
			Expect(status).To(Equal(0))
		})

		It("command exists", func() {
			runner := createRunner()
			Expect(runner.CommandExists("env")).To(BeTrue())
			Expect(runner.CommandExists("absolutely-does-not-exist-ever-please-unicorns")).To(BeFalse())
		})
	})
}
