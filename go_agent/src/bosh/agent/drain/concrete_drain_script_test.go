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
}

func (p fakeDrainParams) JobChange() (change string)       { return p.jobChange }
func (p fakeDrainParams) HashChange() (change string)      { return p.hashChange }
func (p fakeDrainParams) UpdatedPackages() (pkgs []string) { return p.updatedPackages }

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
func init() {
	Describe("Testing with Ginkgo", func() {
		It("run args", func() {
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

			Expect(1).To(Equal(len(runner.RunComplexCommands)))
			Expect(expectedCmd).To(Equal(runner.RunComplexCommands[0]))
		})
		It("run returns parsed s t d o u t", func() {

			drainScript, params, _, _ := buildDrainScript(fakesys.FakeCmdResult{Stdout: "1"})

			value, err := drainScript.Run(params)
			Expect(err).ToNot(HaveOccurred())
			Expect(value).To(Equal(1))
		})
		It("run returns parsed s t d o u t after trimming", func() {

			drainScript, params, _, _ := buildDrainScript(fakesys.FakeCmdResult{Stdout: "-56\n"})

			value, err := drainScript.Run(params)
			Expect(err).ToNot(HaveOccurred())
			Expect(value).To(Equal(-56))
		})
		It("run errors with non integer s t d o u t", func() {

			drainScript, params, _, _ := buildDrainScript(fakesys.FakeCmdResult{Stdout: "hello!"})

			_, err := drainScript.Run(params)
			Expect(err).To(HaveOccurred())
		})
		It("run errors when running command errors", func() {

			drainScript, params, _, _ := buildDrainScript(fakesys.FakeCmdResult{Error: errors.New("woops")})

			_, err := drainScript.Run(params)
			Expect(err).To(HaveOccurred())
		})
		It("exists", func() {

			drainScript, _, _, fs := buildDrainScript(fakesys.FakeCmdResult{Stdout: "1"})

			Expect(drainScript.Exists()).To(BeFalse())

			fs.WriteFile("/fake/script", []byte{})

			Expect(drainScript.Exists()).To(BeTrue())
		})
	})
}
