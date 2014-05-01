package fakes

import (
	boshsys "bosh/system"
)

type FakeBundleInstallCallBack func()

type FakeBundle struct {
	ActionsCalled []string

	InstallSourcePath string
	InstallCallBack   FakeBundleInstallCallBack
	InstallFs         boshsys.FileSystem
	InstallPath       string
	InstallError      error
	Installed         bool

	IsInstalledErr error

	GetDirPath  string
	GetDirFs    boshsys.FileSystem
	GetDirError error

	EnablePath  string
	EnableFs    boshsys.FileSystem
	EnableError error
	Enabled     bool

	DisableErr error

	UninstallErr error
}

func NewFakeBundle() (bundle *FakeBundle) {
	bundle = &FakeBundle{
		ActionsCalled: []string{},
	}
	return
}

func (s *FakeBundle) Install(sourcePath string) (boshsys.FileSystem, string, error) {
	s.InstallSourcePath = sourcePath
	s.Installed = true
	s.ActionsCalled = append(s.ActionsCalled, "Install")
	if s.InstallCallBack != nil {
		s.InstallCallBack()
	}
	return s.InstallFs, s.InstallPath, s.InstallError
}

func (s *FakeBundle) InstallWithoutContents() (boshsys.FileSystem, string, error) {
	s.Installed = true
	s.ActionsCalled = append(s.ActionsCalled, "InstallWithoutContents")
	return s.InstallFs, s.InstallPath, s.InstallError
}

func (s *FakeBundle) GetInstallPath() (boshsys.FileSystem, string, error) {
	return s.GetDirFs, s.GetDirPath, s.GetDirError
}

func (s *FakeBundle) IsInstalled() (bool, error) {
	return s.Installed, s.IsInstalledErr
}

func (s *FakeBundle) Enable() (boshsys.FileSystem, string, error) {
	s.Enabled = true
	s.ActionsCalled = append(s.ActionsCalled, "Enable")
	return s.EnableFs, s.EnablePath, s.EnableError
}

func (s *FakeBundle) Disable() error {
	s.ActionsCalled = append(s.ActionsCalled, "Disable")
	return s.DisableErr
}

func (s *FakeBundle) Uninstall() error {
	s.ActionsCalled = append(s.ActionsCalled, "Uninstall")
	return s.UninstallErr
}
