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
	RunValue   interface{}
	RunPayload []byte
}

func (a *TestAction) Run(payload []byte) (value interface{}, err error) {
	a.RunPayload = payload
	value = a.RunValue
	err = a.RunErr
	return
}
