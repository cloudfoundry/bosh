package action

import (
	boshas "bosh/agent/applier/applyspec"
	bosherr "bosh/errors"
	boshnotif "bosh/notification"
	boshsettings "bosh/settings"
	boshsys "bosh/system"
	"encoding/json"
	"path/filepath"
)

type drainAction struct {
	cmdRunner boshsys.CmdRunner
	fs        boshsys.FileSystem
	notifier  boshnotif.Notifier
}

func newDrain(cmdRunner boshsys.CmdRunner, fs boshsys.FileSystem, notifier boshnotif.Notifier) (drain drainAction) {
	drain.cmdRunner = cmdRunner
	drain.fs = fs
	drain.notifier = notifier
	return
}

func (a drainAction) IsAsynchronous() bool {
	return true
}

type drainType string

const (
	drainTypeUpdate   drainType = "update"
	drainTypeStatus             = "status"
	drainTypeShutdown           = "shutdown"
)

func (a drainAction) Run(drainType drainType, newSpecs ...boshas.V1ApplySpec) (value interface{}, err error) {
	value = 0

	if drainType != drainTypeShutdown {
		return
	}

	err = a.notifier.NotifyShutdown()
	if err != nil {
		err = bosherr.WrapError(err, "Notifying shutdown")
		return
	}

	currentSpec, err := a.getCurrentSpec()
	if err != nil {
		return
	}

	command := boshsys.Command{
		Name: filepath.Join(boshsettings.VCAP_JOBS_DIR, currentSpec.JobSpec.Template, "bin", "drain"),
		Args: []string{"job_shutdown", "hash_unchanged"},
		Env: map[string]string{
			"PATH": "/usr/sbin:/usr/bin:/sbin:/bin",
		},
	}
	a.cmdRunner.RunComplexCommand(command)
	return
}

func (a drainAction) getCurrentSpec() (currentSpec boshas.V1ApplySpec, err error) {
	contents, err := a.fs.ReadFile(filepath.Join(boshsettings.VCAP_BASE_DIR, "bosh", "spec.json"))
	if err != nil {
		err = bosherr.WrapError(err, "Reading json spec file")
		return
	}

	err = json.Unmarshal([]byte(contents), &currentSpec)
	if err != nil {
		err = bosherr.WrapError(err, "Unmarshalling json spec file")
		return
	}

	return
}

func marshalSpec(spec boshas.V1ApplySpec) (contents string, err error) {
	bytes, err := json.Marshal(spec)
	if err != nil {
		return
	}
	contents = string(bytes)
	return
}
