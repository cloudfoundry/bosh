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
	Err     error
	RunArgs []string
}

func (a *TestAction) Run(args []string) (err error) {
	a.RunArgs = args
	return a.Err
}
