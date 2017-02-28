package system_test

import (
	"fmt"
	"strings"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	. "github.com/cloudfoundry/bosh-utils/system"
)

var _ = Describe("ExecError", func() {
	Describe("Error", func() {
		It("returns error message with full stdout and full stderr to aid debugging", func() {
			execErr := NewExecError("fake-cmd", "fake-stdout", "fake-stderr")
			expectedMsg := "Running command: 'fake-cmd', stdout: 'fake-stdout', stderr: 'fake-stderr'"
			Expect(execErr.Error()).To(Equal(expectedMsg))
		})
	})

	Describe("ShortError", func() {
		buildLines := func(start, stop int, suffix string) string {
			var result []string
			for i := start; i <= stop; i++ {
				result = append(result, fmt.Sprintf("%d %s", i, suffix))
			}
			return strings.Join(result, "\n")
		}

		Context("when stdout and stderr contains more than 100 lines", func() {
			It("returns error message with truncated stdout and stderr to 100 lines", func() {
				fullStdout101 := buildLines(1, 101, "stdout")
				truncatedStdout100 := buildLines(2, 101, "stdout")

				fullStderr101 := buildLines(1, 101, "stderr")
				truncatedStderr100 := buildLines(2, 101, "stderr")

				execErr := NewExecError("fake-cmd", fullStdout101, fullStderr101)

				expectedMsg := fmt.Sprintf(
					"Running command: 'fake-cmd', stdout: '%s', stderr: '%s'",
					truncatedStdout100, truncatedStderr100,
				)

				Expect(execErr.ShortError()).To(Equal(expectedMsg))
			})
		})

		Context("when stdout and stderr contains exactly 100 lines", func() {
			It("returns error message with full lines", func() {
				stdout100 := buildLines(1, 100, "stdout")
				stderr100 := buildLines(1, 100, "stderr")
				execErr := NewExecError("fake-cmd", stdout100, stderr100)
				expectedMsg := fmt.Sprintf("Running command: 'fake-cmd', stdout: '%s', stderr: '%s'", stdout100, stderr100)
				Expect(execErr.ShortError()).To(Equal(expectedMsg))
			})
		})

		Context("when stdout and stderr contains less than 100 lines", func() {
			It("returns error message with full lines", func() {
				stdout99 := buildLines(1, 99, "stdout")
				stderr99 := buildLines(1, 99, "stderr")
				execErr := NewExecError("fake-cmd", stdout99, stderr99)
				expectedMsg := fmt.Sprintf("Running command: 'fake-cmd', stdout: '%s', stderr: '%s'", stdout99, stderr99)
				Expect(execErr.ShortError()).To(Equal(expectedMsg))
			})
		})
	})
})
