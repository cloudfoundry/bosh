package fakes

import (
	boshdrain "bosh/agent/drain"
)

type FakeDrainScriptProvider struct {
	NewDrainScriptTemplateName string
	NewDrainScriptDrainScript  *FakeDrainScript
}

func NewFakeDrainScriptProvider() (provider *FakeDrainScriptProvider) {
	provider = &FakeDrainScriptProvider{}
	provider.NewDrainScriptDrainScript = NewFakeDrainScript()
	return
}

func (p *FakeDrainScriptProvider) NewDrainScript(templateName string) (drainScript boshdrain.DrainScript) {
	p.NewDrainScriptTemplateName = templateName
	drainScript = p.NewDrainScriptDrainScript
	return
}
