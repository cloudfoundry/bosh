package action

import (
	boshsettings "bosh/settings"
	boshsys "bosh/system"
	"path/filepath"
)

type applyAction struct {
	fs boshsys.FileSystem
}

func newApply(fs boshsys.FileSystem) (apply applyAction) {
	apply.fs = fs
	return
}

func (a applyAction) Run(args []string) (err error) {
	specFilePath := filepath.Join(boshsettings.VCAP_BASE_DIR, "/bosh/spec.json")
	spec := args[0]

	_, err = a.fs.WriteToFile(specFilePath, spec)
	return
}
