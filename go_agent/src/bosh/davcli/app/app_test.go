package app_test

import (
	"errors"
	"os"
	"path/filepath"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	. "bosh/davcli/app"
	davconf "bosh/davcli/config"
)

type FakeRunner struct {
	Config  davconf.Config
	RunArgs []string
	RunErr  error
}

func (r *FakeRunner) SetConfig(newConfig davconf.Config) {
	r.Config = newConfig
}

func (r *FakeRunner) Run(cmdArgs []string) (err error) {
	r.RunArgs = cmdArgs
	return r.RunErr
}

func pathToFixture(file string) string {
	pwd, err := os.Getwd()
	Expect(err).ToNot(HaveOccurred())

	fixturePath := filepath.Join(pwd, "../../../../fixtures", file)

	absPath, err := filepath.Abs(fixturePath)
	Expect(err).ToNot(HaveOccurred())

	return absPath
}

func init() {
	Describe("Testing with Ginkgo", func() {
		It("runs the put command", func() {
			runner := &FakeRunner{}

			app := New(runner)
			err := app.Run([]string{"dav-cli", "-c", pathToFixture("dav-cli-config.json"), "put", "localFile", "remoteFile"})
			Expect(err).ToNot(HaveOccurred())

			expectedConfig := davconf.Config{
				User:     "some user",
				Password: "some pwd",
				Endpoint: "http://example.com/some/endpoint",
			}

			Expect(runner.Config).To(Equal(expectedConfig))
			Expect(runner.RunArgs).To(Equal([]string{"put", "localFile", "remoteFile"}))
		})

		It("returns error with no config argument", func() {
			runner := &FakeRunner{}

			app := New(runner)
			err := app.Run([]string{"put", "localFile", "remoteFile"})
			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(ContainSubstring("Config file arg `-c` is missing"))
		})

		It("returns error from the cmd runner", func() {
			runner := &FakeRunner{
				RunErr: errors.New("fake-run-error"),
			}

			app := New(runner)
			err := app.Run([]string{"dav-cli", "-c", pathToFixture("dav-cli-config.json"), "put", "localFile", "remoteFile"})
			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(ContainSubstring("fake-run-error"))
		})
	})
}
