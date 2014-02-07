package fakes

import (
	boshsys "bosh/system"
)

type FakeBundle struct {
	InstallFs    boshsys.FileSystem
	InstallPath  string
	InstallError error
	Installed    bool

	GetDirPath  string
	GetDirFs    boshsys.FileSystem
	GetDirError error

	EnablePath    string
	EnableFs      boshsys.FileSystem
	EnableError   error
	Enabled       bool
	ActionsCalled []string
}

func NewFakeBundle() (bundle *FakeBundle) {
	bundle = &FakeBundle{
		ActionsCalled: []string{},
	}
	return
}

func (s *FakeBundle) Install() (fs boshsys.FileSystem, path string, err error) {
	s.ActionsCalled = append(s.ActionsCalled, "Install")
	if s.InstallError != nil {
		err = s.InstallError
		return
	}

	path = s.InstallPath
	fs = s.InstallFs
	s.Installed = true
	return
}

func (s *FakeBundle) GetInstallPath() (fs boshsys.FileSystem, path string, err error) {
	fs = s.GetDirFs
	path = s.GetDirPath
	err = s.GetDirError
	return
}

func (s *FakeBundle) Enable() (fs boshsys.FileSystem, path string, err error) {
	s.ActionsCalled = append(s.ActionsCalled, "Enable")

	if s.EnableError != nil {
		err = s.EnableError
		return
	}
	s.Enabled = true
	fs = s.EnableFs
	path = s.EnablePath
	return
}

func (s *FakeBundle) Disable() (err error) {
	s.ActionsCalled = append(s.ActionsCalled, "Disable")

	return
}

func (s *FakeBundle) Uninstall() (err error) {
	s.ActionsCalled = append(s.ActionsCalled, "Uninstall")

	return
}
