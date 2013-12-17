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

	currentSpec, err := a.getCurrentSpec()
	if err != nil {
		return
	}

	command := boshsys.Command{
		Name: filepath.Join(boshsettings.VCAP_JOBS_DIR, currentSpec.JobSpec.Template, "bin", "drain"),
		Env: map[string]string{
			"PATH": "/usr/sbin:/usr/bin:/sbin:/bin",
		},
	}

	switch drainType {
	case drainTypeUpdate:
		if len(newSpecs) == 0 {
			err = bosherr.New("Drain update requires new spec")
			return
		}
		newSpec := newSpecs[0]
		updatedPkgs := updatedPackages(currentSpec.PackageSpecs, newSpec.PackageSpecs)
		command.Args = append(command.Args, jobChange(currentSpec, newSpec), hashChanged(currentSpec, newSpec))
		command.Args = append(command.Args, updatedPkgs...)
	case drainTypeShutdown:
		err = a.notifier.NotifyShutdown()
		if err != nil {
			err = bosherr.WrapError(err, "Notifying shutdown")
			return
		}
		command.Args = []string{"job_shutdown", "hash_unchanged"}
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

func jobChange(currentSpec, newSpec boshas.V1ApplySpec) string {
	switch {
	case len(currentSpec.Jobs()) == 0:
		return "job_new"
	case currentSpec.JobSpec.Sha1 == newSpec.JobSpec.Sha1:
		return "job_unchanged"
	default:
		return "job_changed"
	}
}

func hashChanged(currentSpec, newSpec boshas.V1ApplySpec) string {
	switch {
	case currentSpec.ConfigurationHash == "":
		return "hash_new"
	case currentSpec.ConfigurationHash == newSpec.ConfigurationHash:
		return "hash_unchanged"
	default:
		return "hash_changed"
	}
}

func updatedPackages(currentPkgs, newPkgs map[string]boshas.PackageSpec) (pkgs []string) {
	for _, pkg := range newPkgs {
		currentPkg, found := currentPkgs[pkg.Name]
		switch {
		case !found:
			pkgs = append(pkgs, pkg.Name)
		case currentPkg.Sha1 != pkg.Sha1:
			pkgs = append(pkgs, pkg.Name)
		}
	}
	return
}
