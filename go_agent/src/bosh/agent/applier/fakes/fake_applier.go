package fakes

import (
	boshas "bosh/agent/applier/applyspec"
)

type FakeApplier struct {
	Prepared                bool
	PrepareDesiredApplySpec boshas.ApplySpec
	PrepareError            error

	Applied               bool
	ApplyCurrentApplySpec boshas.ApplySpec
	ApplyDesiredApplySpec boshas.ApplySpec
	ApplyError            error
}

func NewFakeApplier() *FakeApplier {
	return &FakeApplier{}
}

func (s *FakeApplier) Prepare(desiredApplySpec boshas.ApplySpec) error {
	s.Prepared = true
	s.PrepareDesiredApplySpec = desiredApplySpec
	return s.PrepareError
}

func (s *FakeApplier) Apply(currentApplySpec, desiredApplySpec boshas.ApplySpec) error {
	s.Applied = true
	s.ApplyCurrentApplySpec = currentApplySpec
	s.ApplyDesiredApplySpec = desiredApplySpec
	return s.ApplyError
}
