package fakes

import boshalert "bosh/agent/alert"

type FakeAlertBuilder struct {
	BuildInput boshalert.MonitAlert
	BuildAlert boshalert.Alert
	BuildErr   error
}

func NewFakeAlertBuilder() (fake *FakeAlertBuilder) {
	fake = new(FakeAlertBuilder)
	return
}

func (b *FakeAlertBuilder) Build(input boshalert.MonitAlert) (alert boshalert.Alert, err error) {
	b.BuildInput = input
	alert = b.BuildAlert
	err = b.BuildErr
	return
}
