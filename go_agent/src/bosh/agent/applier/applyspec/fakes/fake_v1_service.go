package fakes

import (
	boshas "bosh/agent/applier/applyspec"
	boshsettings "bosh/settings"
)

type FakeV1Service struct {
	ActionsCalled []string

	Spec   boshas.V1ApplySpec
	GetErr error
	SetErr error

	PopulateDynamicNetworksSpec       boshas.V1ApplySpec
	PopulateDynamicNetworksSettings   boshsettings.Settings
	PopulateDynamicNetworksResultSpec boshas.V1ApplySpec
	PopulateDynamicNetworksErr        error
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

func (s *FakeV1Service) PopulateDynamicNetworks(spec boshas.V1ApplySpec, settings boshsettings.Settings) (boshas.V1ApplySpec, error) {
	s.ActionsCalled = append(s.ActionsCalled, "PopulateDynamicNetworks")
	s.PopulateDynamicNetworksSpec = spec
	s.PopulateDynamicNetworksSettings = settings
	return s.PopulateDynamicNetworksResultSpec, s.PopulateDynamicNetworksErr
}
