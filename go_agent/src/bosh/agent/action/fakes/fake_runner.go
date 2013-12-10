package fakes

import boshaction "bosh/agent/action"

type FakeRunner struct {
	RunAction  boshaction.Action
	RunPayload []byte
	RunValue   interface{}
	RunErr     error
}

func (runner *FakeRunner) Run(action boshaction.Action, payload []byte) (value interface{}, err error) {
	runner.RunAction = action
	runner.RunPayload = payload

	value = runner.RunValue
	err = runner.RunErr
	return
}
