package fakes

import (
	as "bosh/agent/applier/applyspec"
)

type FakeApplier struct {
	Applied               bool
	ApplyCurrentApplySpec as.ApplySpec
	ApplyDesiredApplySpec as.ApplySpec
	ApplyError            error
}

func NewFakeApplier() *FakeApplier {
	return &FakeApplier{}
}

func (s *FakeApplier) Apply(currentApplySpec, desiredApplySpec as.ApplySpec) error {
	s.Applied = true
	s.ApplyCurrentApplySpec = currentApplySpec
	s.ApplyDesiredApplySpec = desiredApplySpec
	return s.ApplyError
}
