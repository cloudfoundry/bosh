package drain

import (
	bosherr "bosh/errors"
	boshsettings "bosh/settings"
	boshsys "bosh/system"
	"path/filepath"
	"strconv"
	"strings"
)

type concreteDrainScript struct {
	fs     boshsys.FileSystem
	runner boshsys.CmdRunner
	path   string
}

func NewConcreteDrainScript(fs boshsys.FileSystem, runner boshsys.CmdRunner, jobTemplateName string) (script concreteDrainScript) {
	script = concreteDrainScript{
		fs:     fs,
		runner: runner,
		path:   filepath.Join(boshsettings.VCAP_JOBS_DIR, jobTemplateName, "bin", "drain"),
	}
	return
}

func (script concreteDrainScript) Exists() bool {
	return script.fs.FileExists(script.path)
}

func (script concreteDrainScript) Run(params DrainScriptParams) (value int, err error) {
	jobChange := params.JobChange()
	hashChange := params.HashChange()
	updatedPkgs := params.UpdatedPackages()

	command := boshsys.Command{
		Name: script.path,
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
