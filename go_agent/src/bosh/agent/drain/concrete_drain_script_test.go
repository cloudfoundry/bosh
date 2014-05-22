package drain_test

import (
	"errors"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	. "bosh/agent/drain"
	boshsys "bosh/system"
	fakesys "bosh/system/fakes"
)

type fakeDrainParams struct {
	jobChange       string
	hashChange      string
	updatedPackages []string

	jobState     string
	jobNextState string
}

func (p fakeDrainParams) JobChange() (change string)       { return p.jobChange }
func (p fakeDrainParams) HashChange() (change string)      { return p.hashChange }
func (p fakeDrainParams) UpdatedPackages() (pkgs []string) { return p.updatedPackages }

func (p fakeDrainParams) JobState() (string, error)     { return p.jobState, nil }
func (p fakeDrainParams) JobNextState() (string, error) { return p.jobNextState, nil }

func buildDrainScript(commandResult fakesys.FakeCmdResult) (
	drainScript ConcreteDrainScript,
	params fakeDrainParams,
	runner *fakesys.FakeCmdRunner,
	fs *fakesys.FakeFileSystem,
) {
	fs = fakesys.NewFakeFileSystem()
	runner = fakesys.NewFakeCmdRunner()
	drainScript = NewConcreteDrainScript(fs, runner, "/fake/script")
	params = fakeDrainParams{
		jobChange:       "job_shutdown",
		hashChange:      "hash_unchanged",
		updatedPackages: []string{"foo", "bar"},
	}

	runner.AddCmdResult("/fake/script"+" job_shutdown hash_unchanged foo bar", commandResult)

	return
}

var _ = Describe("ConcreteDrainScript", func() {
	Describe("Run", func() {
		It("runs drain script", func() {
			drainScript, params, runner, _ := buildDrainScript(fakesys.FakeCmdResult{Stdout: "1"})

			_, err := drainScript.Run(params)
			Expect(err).ToNot(HaveOccurred())

			expectedCmd := boshsys.Command{
				Name: "/fake/script",
				Args: []string{"job_shutdown", "hash_unchanged", "foo", "bar"},
				Env: map[string]string{
					"PATH": "/usr/sbin:/usr/bin:/sbin:/bin",
				},
			}

			Expect(len(runner.RunComplexCommands)).To(Equal(1))
			Expect(runner.RunComplexCommands[0]).To(Equal(expectedCmd))
		})

		It("returns parsed stdout", func() {
			drainScript, params, _, _ := buildDrainScript(fakesys.FakeCmdResult{Stdout: "1"})

			value, err := drainScript.Run(params)
			Expect(err).ToNot(HaveOccurred())
			Expect(value).To(Equal(1))
		})

		It("returns parsed stdout after trimming", func() {
			drainScript, params, _, _ := buildDrainScript(fakesys.FakeCmdResult{Stdout: "-56\n"})

			value, err := drainScript.Run(params)
			Expect(err).ToNot(HaveOccurred())
			Expect(value).To(Equal(-56))
		})

		It("returns error with non integer stdout", func() {
			drainScript, params, _, _ := buildDrainScript(fakesys.FakeCmdResult{Stdout: "hello!"})

			_, err := drainScript.Run(params)
			Expect(err).To(HaveOccurred())
		})

		It("returns error when running command errors", func() {
			drainScript, params, _, _ := buildDrainScript(fakesys.FakeCmdResult{Error: errors.New("woops")})

			_, err := drainScript.Run(params)
			Expect(err).To(HaveOccurred())
		})
	})

	Describe("Exists", func() {
		It("returns bool", func() {
			drainScript, _, _, fs := buildDrainScript(fakesys.FakeCmdResult{Stdout: "1"})

			Expect(drainScript.Exists()).To(BeFalse())

			fs.WriteFile("/fake/script", []byte{})
			Expect(drainScript.Exists()).To(BeTrue())
		})
	})
})
