package testhelpers

import boshaction "bosh/agent/action"

type FakeFactory struct {
	CreateMethod string
	CreateAction *TestAction
}

func (f *FakeFactory) Create(method string) (action boshaction.Action) {
	f.CreateMethod = method
	action = f.CreateAction
	return
}

type TestAction struct {
	RunErr     error
	RunPayload []byte
}

func (a *TestAction) Run(payload []byte) (err error) {
	a.RunPayload = payload
	return a.RunErr
}
