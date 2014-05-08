package fakes

import (
	boshas "bosh/agent/applier/applyspec"
)

type FakeV1Service struct {
	ActionsCalled []string

	Spec   boshas.V1ApplySpec
	GetErr error
	SetErr error

	ResolveDynamicNetworksSpec       boshas.V1ApplySpec
	ResolveDynamicNetworksResultSpec boshas.V1ApplySpec
	ResolveDynamicNetworksErr        error
}

func NewFakeV1Service() *FakeV1Service {
	return &FakeV1Service{}
}

func (s *FakeV1Service) Get() (boshas.V1ApplySpec, error) {
	s.ActionsCalled = append(s.ActionsCalled, "Get")
	return s.Spec, s.GetErr
}

func (s *FakeV1Service) Set(spec boshas.V1ApplySpec) error {
	s.ActionsCalled = append(s.ActionsCalled, "Set")
	s.Spec = spec
	return s.SetErr
}

func (s *FakeV1Service) ResolveDynamicNetworks(spec boshas.V1ApplySpec) (boshas.V1ApplySpec, error) {
	s.ActionsCalled = append(s.ActionsCalled, "ResolveDynamicNetworks")
	s.ResolveDynamicNetworksSpec = spec
	return s.ResolveDynamicNetworksResultSpec, s.ResolveDynamicNetworksErr
}
