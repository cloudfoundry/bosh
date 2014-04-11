package fakes

import (
	boshalert "bosh/agent/alert"
)

type FakeAlertBuilder struct {
	BuildInput boshalert.MonitAlert
	BuildAlert boshalert.Alert
	BuildErr   error
}

func NewFakeAlertBuilder() *FakeAlertBuilder {
	return &FakeAlertBuilder{}
}

func (b *FakeAlertBuilder) Build(input boshalert.MonitAlert) (boshalert.Alert, error) {
	b.BuildInput = input
	return b.BuildAlert, b.BuildErr
}
