package fakes

import (
	boshaction "bosh/agent/action"
)

type FakeRunner struct {
	RunAction  boshaction.Action
	RunPayload []byte
	RunValue   interface{}
	RunErr     error

	ResumeAction  boshaction.Action
	ResumePayload []byte
	ResumeValue   interface{}
	ResumeErr     error
}

func (runner *FakeRunner) Run(action boshaction.Action, payload []byte) (interface{}, error) {
	runner.RunAction = action
	runner.RunPayload = payload
	return runner.RunValue, runner.RunErr
}

func (runner *FakeRunner) Resume(action boshaction.Action, payload []byte) (interface{}, error) {
	runner.ResumeAction = action
	runner.ResumePayload = payload
	return runner.ResumeValue, runner.ResumeErr
}
