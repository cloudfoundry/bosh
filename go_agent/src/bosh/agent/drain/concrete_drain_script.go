package drain

import (
	bosherr "bosh/errors"
	boshsys "bosh/system"
	"strconv"
	"strings"
)

type ConcreteDrainScript struct {
	fs              boshsys.FileSystem
	runner          boshsys.CmdRunner
	drainScriptPath string
}

func NewConcreteDrainScript(
	fs boshsys.FileSystem,
	runner boshsys.CmdRunner,
	drainScriptPath string,
) (script ConcreteDrainScript) {
	script = ConcreteDrainScript{
		fs:              fs,
		runner:          runner,
		drainScriptPath: drainScriptPath,
	}
	return
}

func (script ConcreteDrainScript) Exists() bool {
	return script.fs.FileExists(script.drainScriptPath)
}

func (script ConcreteDrainScript) Path() string {
	return script.drainScriptPath
}

func (script ConcreteDrainScript) Run(params DrainScriptParams) (int, error) {
	jobChange := params.JobChange()
	hashChange := params.HashChange()
	updatedPkgs := params.UpdatedPackages()

	command := boshsys.Command{
		Name: script.drainScriptPath,
		Env: map[string]string{
			"PATH": "/usr/sbin:/usr/bin:/sbin:/bin",
		},
	}
	command.Args = append(command.Args, jobChange, hashChange)
	command.Args = append(command.Args, updatedPkgs...)

	stdout, _, _, err := script.runner.RunComplexCommand(command)
	if err != nil {
		return 0, bosherr.WrapError(err, "Running drain script")
	}

	value, err := strconv.Atoi(strings.TrimSpace(stdout))
	if err != nil {
		return 0, bosherr.WrapError(err, "Script did not return a signed integer")
	}

	return value, nil
}
