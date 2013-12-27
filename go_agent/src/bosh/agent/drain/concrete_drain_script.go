package drain

import (
	bosherr "bosh/errors"
	boshsys "bosh/system"
	"strconv"
	"strings"
)

type concreteDrainScript struct {
	fs              boshsys.FileSystem
	runner          boshsys.CmdRunner
	drainScriptPath string
}

func NewConcreteDrainScript(fs boshsys.FileSystem, runner boshsys.CmdRunner, drainScriptPath string) (script concreteDrainScript) {
	script = concreteDrainScript{
		fs:              fs,
		runner:          runner,
		drainScriptPath: drainScriptPath,
	}
	return
}

func (script concreteDrainScript) Exists() bool {
	return script.fs.FileExists(script.drainScriptPath)
}

func (script concreteDrainScript) Run(params DrainScriptParams) (value int, err error) {
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

	stdout, _, err := script.runner.RunComplexCommand(command)
	if err != nil {
		err = bosherr.WrapError(err, "Running drain script")
		return
	}
	value, err = strconv.Atoi(strings.TrimSpace(stdout))
	if err != nil {
		err = bosherr.WrapError(err, "Script did not return a signed integer")
	}
	return
}
