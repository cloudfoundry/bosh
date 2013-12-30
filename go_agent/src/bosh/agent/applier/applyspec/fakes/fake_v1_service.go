package fakes

import boshas "bosh/agent/applier/applyspec"

type FakeV1Service struct {
	Spec boshas.V1ApplySpec

	GetErr error
	SetErr error
}

func NewFakeV1Service() (service *FakeV1Service) {
	service = &FakeV1Service{}
	return
}

func (s *FakeV1Service) Get() (spec boshas.V1ApplySpec, err error) {
	if s.GetErr != nil {
		err = s.GetErr
	}
	spec = s.Spec
	return
}

func (s *FakeV1Service) Set(spec boshas.V1ApplySpec) (err error) {
	if s.SetErr != nil {
		err = s.SetErr
		return
	}
	s.Spec = spec
	return
}
