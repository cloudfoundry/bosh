package fakes

import (
	"errors"
	"path/filepath"

	fakesys "bosh/system/fakes"
)

type FakeCdrom struct {
	WaitForMediaError error
	MountError        error
	UnmountError      error
	EjectError        error

	MediaAvailable    bool
	Fs                *fakesys.FakeFileSystem
	MediaFilePath     string
	MediaFileContents string

	MountMountPath string
	Mounted        bool
}

func NewFakeCdrom(fs *fakesys.FakeFileSystem, filepath, contents string) *FakeCdrom {
	return &FakeCdrom{
		Fs:                fs,
		MediaFilePath:     filepath,
		MediaFileContents: contents,
	}
}

func (cdrom *FakeCdrom) WaitForMedia() error {
	if cdrom.WaitForMediaError != nil {
		return cdrom.WaitForMediaError
	}

	cdrom.MediaAvailable = true

	return nil
}

func (cdrom *FakeCdrom) Mount(mountPath string) error {
	switch {
	case !cdrom.MediaAvailable:
		return errors.New("media not available")
	case cdrom.Mounted:
		return errors.New("already mounted")
	case cdrom.MountError != nil:
		return cdrom.MountError
	}

	cdrom.MountMountPath = mountPath

	err := cdrom.Fs.WriteFileString(filepath.Join(mountPath, cdrom.MediaFilePath), cdrom.MediaFileContents)
	if err != nil {
		return err
	}

	cdrom.Mounted = true

	return nil
}

func (cdrom *FakeCdrom) Unmount() error {
	switch {
	case !cdrom.Mounted:
		return errors.New("device not mounted")
	case cdrom.UnmountError != nil:
		return cdrom.UnmountError
	}

	err := cdrom.Fs.RemoveAll(filepath.Join(cdrom.MountMountPath, cdrom.MediaFilePath))
	if err != nil {
		return err
	}

	cdrom.Mounted = false

	return nil
}

func (cdrom *FakeCdrom) Eject() (err error) {
	switch {
	case cdrom.Mounted:
		return errors.New("device busy")
	case cdrom.EjectError != nil:
		return cdrom.EjectError
	}

	cdrom.MediaAvailable = false

	return
}
