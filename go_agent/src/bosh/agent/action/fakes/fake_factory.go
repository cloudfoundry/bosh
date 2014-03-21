package fakes

import (
	boshaction "bosh/agent/action"
	"errors"
)

type FakeFactory struct {
	CreateMethod string
	CreateAction *TestAction
	CreateErr    bool
}

func (f *FakeFactory) Create(method string) (action boshaction.Action, err error) {
	f.CreateMethod = method
	action = f.CreateAction

	if f.CreateErr {
		err = errors.New("Error creating action")
	}
	return
}

type TestAction struct {
	Asynchronous bool
	Persistent   bool

	ResumeValue interface{}
	ResumeErr   error
	Resumed     bool
}

func (a *TestAction) IsAsynchronous() bool {
	return a.Asynchronous
}

func (a *TestAction) IsPersistent() bool {
	return a.Persistent
}

func (a *TestAction) Run(payload []byte) (interface{}, error) {
	return nil, nil
}

func (a *TestAction) Resume() (interface{}, error) {
	a.Resumed = true
	return a.ResumeValue, a.ResumeErr
}
