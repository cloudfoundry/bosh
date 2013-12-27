package drain

import (
	boshdirs "bosh/settings/directories"
	boshsys "bosh/system"
	"path/filepath"
)

type DrainScriptProvider struct {
	cmdRunner   boshsys.CmdRunner
	fs          boshsys.FileSystem
	dirProvider boshdirs.DirectoriesProvider
}

func NewDrainScriptProvider(cmdRunner boshsys.CmdRunner, fs boshsys.FileSystem, dirProvider boshdirs.DirectoriesProvider) (provider DrainScriptProvider) {
	provider.cmdRunner = cmdRunner
	provider.fs = fs
	provider.dirProvider = dirProvider
	return
}

func (p DrainScriptProvider) NewDrainScript(templateName string) (drainScript concreteDrainScript) {
	scriptPath := filepath.Join(p.dirProvider.JobsDir(), templateName, "bin", "drain")
	drainScript = NewConcreteDrainScript(p.fs, p.cmdRunner, scriptPath)
	return
}
