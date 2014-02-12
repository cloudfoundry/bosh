package system_test

import (
	boshlog "bosh/logger"
	. "bosh/system"
	. "github.com/onsi/ginkgo"
	"github.com/stretchr/testify/assert"
)

func createRunner() (r CmdRunner) {
	r = NewExecCmdRunner(boshlog.NewLogger(boshlog.LEVEL_NONE))
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
			assert.NoError(GinkgoT(), err)
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
			assert.NoError(GinkgoT(), err)
			assert.Empty(GinkgoT(), stderr)
			assert.Contains(GinkgoT(), stdout, "FOO=BAR")
			assert.Contains(GinkgoT(), stdout, "PATH=")
		})
		It("run command", func() {

			runner := createRunner()

			stdout, stderr, err := runner.RunCommand("echo", "Hello World!")
			assert.NoError(GinkgoT(), err)
			assert.Empty(GinkgoT(), stderr)
			assert.Equal(GinkgoT(), stdout, "Hello World!\n")
		})
		It("run command with error output", func() {

			runner := createRunner()

			stdout, stderr, err := runner.RunCommand("sh", "-c", "echo error-output >&2")
			assert.NoError(GinkgoT(), err)
			assert.Contains(GinkgoT(), stderr, "error-output")
			assert.Empty(GinkgoT(), stdout)
		})
		It("run command with error", func() {

			runner := createRunner()

			stdout, stderr, err := runner.RunCommand("false")
			assert.Error(GinkgoT(), err)
			assert.Equal(GinkgoT(), err.Error(), "Running command: 'false', stdout: '', stderr: '': exit status 1")
			assert.Empty(GinkgoT(), stderr)
			assert.Empty(GinkgoT(), stdout)
		})
		It("run command with error with args", func() {

			runner := createRunner()

			stdout, stderr, err := runner.RunCommand("false", "second arg")
			assert.Error(GinkgoT(), err)
			assert.Equal(GinkgoT(), err.Error(), "Running command: 'false second arg', stdout: '', stderr: '': exit status 1")
			assert.Empty(GinkgoT(), stderr)
			assert.Empty(GinkgoT(), stdout)
		})
		It("run command with cmd not found", func() {

			runner := createRunner()

			stdout, stderr, err := runner.RunCommand("something that does not exist")
			assert.Error(GinkgoT(), err)
			assert.Contains(GinkgoT(), err.Error(), "not found")
			assert.Empty(GinkgoT(), stderr)
			assert.Empty(GinkgoT(), stdout)
		})
		It("run command with input", func() {

			runner := createRunner()

			stdout, stderr, err := runner.RunCommandWithInput("foo\nbar\nbaz", "grep", "ba")

			assert.NoError(GinkgoT(), err)
			assert.Equal(GinkgoT(), "bar\nbaz\n", stdout)
			assert.Empty(GinkgoT(), stderr)
		})
		It("command exists", func() {

			runner := createRunner()

			assert.True(GinkgoT(), runner.CommandExists("env"))
			assert.False(GinkgoT(), runner.CommandExists("absolutely-does-not-exist-ever-please-unicorns"))
		})
	})
}
