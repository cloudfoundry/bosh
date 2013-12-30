package fakes

import (
	boshdrain "bosh/agent/drain"
)

type FakeDrainScript struct {
	ExistsBool    bool
	DidRun        bool
	RunExitStatus int
	RunError      error
	RunParams     boshdrain.DrainScriptParams
}

func NewFakeDrainScript() (script *FakeDrainScript) {
	script = &FakeDrainScript{
		RunExitStatus: 1,
	}
	return
}

func (script *FakeDrainScript) Exists() bool {
	return script.ExistsBool
}

func (script *FakeDrainScript) Path() string {
	return "/fake/path"
}

func (script *FakeDrainScript) Run(params boshdrain.DrainScriptParams) (value int, err error) {
	script.DidRun = true
	script.RunParams = params
	value = script.RunExitStatus
	err = script.RunError
	return
}
