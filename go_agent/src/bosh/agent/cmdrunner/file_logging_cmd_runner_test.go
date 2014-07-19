package cmdrunner_test

import (
	"errors"
	"os"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	. "bosh/agent/cmdrunner"
	boshsys "bosh/system"
	fakesys "bosh/system/fakes"
)

var _ = Describe("FileLogginCmdRunner", func() {
	var (
		runner    CmdRunner
		cmd       boshsys.Command
		fs        *fakesys.FakeFileSystem
		cmdRunner *fakesys.FakeCmdRunner
	)

	BeforeEach(func() {
		fs = fakesys.NewFakeFileSystem()
		cmdRunner = fakesys.NewFakeCmdRunner()

		runner = NewFileLoggingCmdRunner(fs, cmdRunner, "/fake-base-dir", 15)

		cmd = boshsys.Command{
			Name: "bash",
			Args: []string{"-x", "packaging"},
			Env: map[string]string{
				"BOSH_COMPILE_TARGET":  "/fake-compile-dir/pkg_name",
				"BOSH_INSTALL_TARGET":  "/fake-dir/packages/pkg_name",
				"BOSH_PACKAGE_NAME":    "pkg_name",
				"BOSH_PACKAGE_VERSION": "pkg_version",
			},
			WorkingDir: "/fake-compile-dir/pkg_name",
		}
	})

	Describe("RunCommand", func() {
		It("returns an error if it fails to create logs directory", func() {
			fs.MkdirAllError = errors.New("fake-mkdir-file-error")
			_, err := runner.RunCommand("fake-log-dir-name", "fake-log-file-name", cmd)
			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(ContainSubstring("fake-mkdir-file-error"))
		})

		It("returns an error if it fails to save output", func() {
			fs.OpenFileErr = errors.New("fake-open-file-error")
			_, err := runner.RunCommand("fake-log-dir-name", "fake-log-file-name", cmd)
			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(ContainSubstring("fake-open-file-error"))
		})

		It("cleans logs directory", func() {
			fs.MkdirAll("/fake-base-dir/fake-log-dir-name/", os.FileMode(0750))
			fs.WriteFile("/fake-base-dir/fake-log-dir-name/old-file", []byte("test-data"))
			_, err := runner.RunCommand("fake-log-dir-name", "fake-log-file-name", cmd)
			Expect(err).ToNot(HaveOccurred())
			Expect(fs.FileExists("/fake-base-dir/fake-log-dir-name/old-file")).To(BeFalse())
		})

		Context("when script succeeds", func() {
			BeforeEach(func() {
				cmdRunner.AddCmdResult("bash -x packaging",
					fakesys.FakeCmdResult{
						Stdout:     "fake-stdout",
						Stderr:     "fake-stderr",
						ExitStatus: 0,
					})
			})

			It("returns correct result", func() {
				expectedResult := &CmdResult{
					IsStdoutTruncated: false,
					Stdout:            []byte("fake-stdout"),
					Stderr:            []byte("fake-stderr"),
					ExitStatus:        0,
				}

				result, err := runner.RunCommand("fake-log-dir-name", "fake-log-file-name", cmd)
				Expect(err).ToNot(HaveOccurred())
				Expect(result).To(Equal(expectedResult))
			})

			It("saves stdout to log file", func() {
				_, err := runner.RunCommand("fake-log-dir-name", "fake-log-file-name", cmd)
				Expect(err).ToNot(HaveOccurred())

				Expect(fs.FileExists("/fake-base-dir/fake-log-dir-name/fake-log-file-name.stdout.log")).To(BeTrue())
				stdout, err := fs.ReadFileString("/fake-base-dir/fake-log-dir-name/fake-log-file-name.stdout.log")
				Expect(err).ToNot(HaveOccurred())
				Expect(stdout).To(Equal("fake-stdout"))
			})

			It("saves stderr to log file", func() {
				_, err := runner.RunCommand("fake-log-dir-name", "fake-log-file-name", cmd)
				Expect(err).ToNot(HaveOccurred())

				Expect(fs.FileExists("/fake-base-dir/fake-log-dir-name/fake-log-file-name.stderr.log")).To(BeTrue())
				stdout, err := fs.ReadFileString("/fake-base-dir/fake-log-dir-name/fake-log-file-name.stderr.log")
				Expect(err).ToNot(HaveOccurred())
				Expect(stdout).To(Equal("fake-stderr"))
			})
		})

		Context("when script fails with error", func() {
			BeforeEach(func() {
				cmdRunner.AddCmdResult("bash -x packaging",
					fakesys.FakeCmdResult{
						Stdout:     "fake-stdout",
						Stderr:     "fake-stderr",
						ExitStatus: 1,
						Error:      errors.New("fake-result-error"),
					})
			})

			It("returns script error", func() {
				result, err := runner.RunCommand("fake-log-dir-name", "fake-log-file-name", cmd)

				Expect(result).To(BeNil())
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(Equal("Command exited with 1; Stdout: fake-stdout, Stderr: fake-stderr"))
			})

			It("saves stdout to log file", func() {
				_, err := runner.RunCommand("fake-log-dir-name", "fake-log-file-name", cmd)
				Expect(err).To(HaveOccurred())

				Expect(fs.FileExists("/fake-base-dir/fake-log-dir-name/fake-log-file-name.stdout.log")).To(BeTrue())
				stdout, err := fs.ReadFileString("/fake-base-dir/fake-log-dir-name/fake-log-file-name.stdout.log")
				Expect(err).ToNot(HaveOccurred())
				Expect(stdout).To(Equal("fake-stdout"))
			})

			It("saves stderr to log file", func() {
				_, err := runner.RunCommand("fake-log-dir-name", "fake-log-file-name", cmd)
				Expect(err).To(HaveOccurred())

				Expect(fs.FileExists("/fake-base-dir/fake-log-dir-name/fake-log-file-name.stderr.log")).To(BeTrue())
				stdout, err := fs.ReadFileString("/fake-base-dir/fake-log-dir-name/fake-log-file-name.stderr.log")
				Expect(err).ToNot(HaveOccurred())
				Expect(stdout).To(Equal("fake-stderr"))
			})
		})

		Context("when script output is too long", func() {
			It("truncates stdout and stderr to truncate length", func() {
				cmdRunner.AddCmdResult("bash -x packaging",
					fakesys.FakeCmdResult{
						Stdout:     "fake-long-output-stdout",
						Stderr:     "fake-long-output-stderr",
						ExitStatus: 0,
					})

				expectedResult := &CmdResult{
					IsStdoutTruncated: true,
					IsStderrTruncated: true,
					Stdout:            []byte("g-output-stdout"),
					Stderr:            []byte("g-output-stderr"),
					ExitStatus:        0,
				}

				result, err := runner.RunCommand("fake-log-dir-name", "fake-log-file-name", cmd)
				Expect(err).ToNot(HaveOccurred())
				Expect(result).To(Equal(expectedResult))
			})

			It("truncates stdout and stderr to nearest line break", func() {
				cmdRunner.AddCmdResult("bash -x packaging",
					fakesys.FakeCmdResult{
						Stdout:     "fake-long\n\routput-stdout",
						Stderr:     "fake-long\noutput-stderr",
						ExitStatus: 0,
					})

				expectedResult := &CmdResult{
					IsStdoutTruncated: true,
					IsStderrTruncated: true,
					Stdout:            []byte("output-stdout"),
					Stderr:            []byte("output-stderr"),
					ExitStatus:        0,
				}

				result, err := runner.RunCommand("fake-log-dir-name", "fake-log-file-name", cmd)
				Expect(err).ToNot(HaveOccurred())
				Expect(result).To(Equal(expectedResult))
			})

			It("does not truncates stdout and stderr to nearest line break if line break will cut off more than 25% of data", func() {
				cmdRunner.AddCmdResult("bash -x packaging",
					fakesys.FakeCmdResult{
						Stdout:     "fake-long-output-std\nout",
						Stderr:     "fake-long-output-std\nerr",
						ExitStatus: 0,
					})

				expectedResult := &CmdResult{
					IsStdoutTruncated: true,
					IsStderrTruncated: true,
					Stdout:            []byte("-output-std\nout"),
					Stderr:            []byte("-output-std\nerr"),
					ExitStatus:        0,
				}

				result, err := runner.RunCommand("fake-log-dir-name", "fake-log-file-name", cmd)
				Expect(err).ToNot(HaveOccurred())
				Expect(result).To(Equal(expectedResult))
			})

			It("truncates stdout and stderr to nearest full UTF encoded string", func() {
				cmdRunner.AddCmdResult("bash -x packaging",
					fakesys.FakeCmdResult{
						Stdout:     "приветstdout",
						Stderr:     "приветstderr",
						ExitStatus: 0,
					})

				expectedResult := &CmdResult{
					IsStdoutTruncated: true,
					IsStderrTruncated: true,
					Stdout:            []byte("иветstdout"),
					Stderr:            []byte("иветstderr"),
					ExitStatus:        0,
				}

				result, err := runner.RunCommand("fake-log-dir-name", "fake-log-file-name", cmd)
				Expect(err).ToNot(HaveOccurred())
				Expect(result).To(Equal(expectedResult))
			})

			It("returns an error with truncated stdout/stderr", func() {
				cmdRunner.AddCmdResult("bash -x packaging",
					fakesys.FakeCmdResult{
						Stdout:     "fake-long-output-stdout",
						Stderr:     "fake-long-output-stderr",
						ExitStatus: 1,
						Error:      errors.New("fake-packaging-error"),
					})

				result, err := runner.RunCommand("fake-log-dir-name", "fake-log-file-name", cmd)

				Expect(result).To(BeNil())
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(Equal("Command exited with 1; Truncated stdout: g-output-stdout, Truncated stderr: g-output-stderr"))
			})
		})
	})
})
