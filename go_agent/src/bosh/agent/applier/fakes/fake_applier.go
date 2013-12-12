package fakes

import as "bosh/agent/applier/applyspec"

type FakeApplier struct {
	Applied        bool
	ApplyApplySpec as.ApplySpec
	ApplyError     error
}

func NewFakeApplier() *FakeApplier {
	return &FakeApplier{}
}

func (s *FakeApplier) Apply(applySpec as.ApplySpec) error {
	if s.ApplyError != nil {
		return s.ApplyError
	}

	s.ApplyApplySpec = applySpec
	s.Applied = true
	return nil
}
