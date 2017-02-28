// +build !windows

package system_test

import (
	"fmt"
	"io/ioutil"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	boshlog "github.com/cloudfoundry/bosh-utils/logger"
	. "github.com/cloudfoundry/bosh-utils/system"
)

var _ = Describe("execProcess", func() {
	Describe("TerminateNicely", func() {
		var (
			buildDir string
			logger   boshlog.Logger
		)

		BeforeEach(func() {
			logger = boshlog.NewLogger(boshlog.LevelNone)
		})

		hasProcessesFromBuildDir := func() (bool, string) {
			// Make sure to show all processes on the system
			output, err := exec.Command("ps", "-A", "-o", "pid,args").Output()
			Expect(err).ToNot(HaveOccurred())

			// Cannot check for PID existence directly because
			// PID could have been recycled by the OS; make sure it's not the same process
			for _, line := range strings.Split(strings.TrimSpace(string(output)), "\n") {
				if strings.Contains(line, buildDir) {
					return true, line
				}
			}

			return false, ""
		}

		expectProcessesToNotExist := func() {
			exists, ps := hasProcessesFromBuildDir()
			Expect(exists).To(BeFalse(), "Expected following process to not exist %s", ps)
		}

		BeforeEach(func() {
			var (
				err error
			)

			buildDir, err = ioutil.TempDir("", "TerminateNicely")
			Expect(err).ToNot(HaveOccurred())

			exesToCompile := []string{
				"exe_exits",
				"child_ignore_term",
				"child_term",
				"parent_ignore_term",
				"parent_term",
			}

			for _, exe := range exesToCompile {
				dst := filepath.Join(buildDir, exe)
				src := filepath.Join("exec_cmd_runner_fixtures", exe+".go")
				err := exec.Command("go", "build", "-o", dst, src).Run()
				Expect(err).ToNot(HaveOccurred())
			}
		})

		AfterEach(func() {
			os.RemoveAll(buildDir)
		})

		//for _, keepAttached := range []bool{true, false} {
		for _, keepAttached := range []bool{false} {
			keepAttached := keepAttached

			Describe(fmt.Sprintf("running with process attached=%b", keepAttached), func() {
				Context("when parent and child terminate after receiving SIGTERM", func() {
					It("sends term signal to the whole group and returns with exit status that parent exited", func() {
						command := exec.Command(filepath.Join(buildDir, "parent_term"))
						process := NewExecProcess(command, keepAttached, logger)
						err := process.Start()
						Expect(err).ToNot(HaveOccurred())

						// Wait for script to start and output pids
						time.Sleep(2 * time.Second)

						waitCh := process.Wait()

						err = process.TerminateNicely(1 * time.Minute)
						Expect(err).ToNot(HaveOccurred())

						result := <-waitCh
						Expect(result.Error).To(HaveOccurred())

						// Parent exit code is returned
						// bash adds 128 to signal status as exit code
						Expect(result.ExitStatus).To(Equal(13))

						// Term signal was sent to all processes in the group
						Expect(result.Stdout).To(ContainSubstring("Parent received SIGTERM"))
						Expect(result.Stdout).To(ContainSubstring("Child received SIGTERM"))

						// All processes are gone
						expectProcessesToNotExist()
					})
				})

				Context("when parent and child do not exit after receiving SIGTERM in small amount of time", func() {
					It("sends kill signal to the whole group and returns with ? exit status", func() {
						command := exec.Command(filepath.Join(buildDir, "parent_ignore_term"))
						process := NewExecProcess(command, keepAttached, logger)
						err := process.Start()
						Expect(err).ToNot(HaveOccurred())

						// Wait for script to start and output pids
						time.Sleep(2 * time.Second)

						waitCh := process.Wait()

						err = process.TerminateNicely(2 * time.Second)
						Expect(err).ToNot(HaveOccurred())

						result := <-waitCh
						Expect(result.Error).To(HaveOccurred())

						// Parent exit code is returned
						Expect(result.ExitStatus).To(Equal(128 + 9))

						// Term signal was sent to all processes in the group before kill
						Expect(result.Stdout).To(ContainSubstring("Parent received SIGTERM"))
						Expect(result.Stdout).To(ContainSubstring("Child received SIGTERM"))

						// Parent and child are killed
						expectProcessesToNotExist()
					})
				})

				Context("when parent and child already exited before calling TerminateNicely", func() {
					It("returns without an error since all processes are gone", func() {
						command := exec.Command(filepath.Join(buildDir, "exe_exits"))
						process := NewExecProcess(command, keepAttached, logger)
						err := process.Start()
						Expect(err).ToNot(HaveOccurred())

						// Wait for script to exit
						for i := 0; i < 20; i++ {
							if exists, _ := hasProcessesFromBuildDir(); !exists {
								break
							}
							if i == 19 {
								Fail("Expected process did not exit fast enough")
							}
							time.Sleep(500 * time.Millisecond)
						}

						waitCh := process.Wait()

						err = process.TerminateNicely(2 * time.Second)
						Expect(err).ToNot(HaveOccurred())

						result := <-waitCh
						Expect(result.Error).ToNot(HaveOccurred())
						Expect(result.Stdout).To(Equal(""))
						Expect(result.Stderr).To(Equal(""))
						Expect(result.ExitStatus).To(Equal(0))
					})
				})
			})
		}
	})
})
