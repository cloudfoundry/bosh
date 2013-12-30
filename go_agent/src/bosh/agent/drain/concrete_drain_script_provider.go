package drain

import (
	boshdirs "bosh/settings/directories"
	boshsys "bosh/system"
	"path/filepath"
)

type ConcreteDrainScriptProvider struct {
	cmdRunner   boshsys.CmdRunner
	fs          boshsys.FileSystem
	dirProvider boshdirs.DirectoriesProvider
}

func NewConcreteDrainScriptProvider(
	cmdRunner boshsys.CmdRunner,
	fs boshsys.FileSystem,
	dirProvider boshdirs.DirectoriesProvider,
) (provider ConcreteDrainScriptProvider) {
	provider.cmdRunner = cmdRunner
	provider.fs = fs
	provider.dirProvider = dirProvider
	return
}

func (p ConcreteDrainScriptProvider) NewDrainScript(templateName string) (drainScript DrainScript) {
	scriptPath := filepath.Join(p.dirProvider.JobsDir(), templateName, "bin", "drain")
	drainScript = NewConcreteDrainScript(p.fs, p.cmdRunner, scriptPath)
	return
}
