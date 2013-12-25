package drain

import (
	boshsys "bosh/system"
)

type DrainScriptProvider struct {
	cmdRunner boshsys.CmdRunner
	fs        boshsys.FileSystem
}

func NewDrainScriptProvider(cmdRunner boshsys.CmdRunner, fs boshsys.FileSystem) (provider DrainScriptProvider) {
	provider.cmdRunner = cmdRunner
	provider.fs = fs
	return
}

func (p DrainScriptProvider) NewDrainScript(templateName string) (drainScript concreteDrainScript) {
	drainScript = NewConcreteDrainScript(p.fs, p.cmdRunner, templateName)
	return
}
