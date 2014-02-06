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

	EnablePath  string
	EnableFs    boshsys.FileSystem
	EnableError error
	Enabled     bool
}

func NewFakeBundle() *FakeBundle {
	return &FakeBundle{}
}

func (s *FakeBundle) Install() (fs boshsys.FileSystem, path string, err error) {
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
	if s.EnableError != nil {
		err = s.EnableError
		return
	}
	s.Enabled = true
	return
}
