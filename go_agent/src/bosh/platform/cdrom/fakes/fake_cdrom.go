package fakes

import (
	fakesys "bosh/system/fakes"
	"errors"
	"path/filepath"
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

func NewFakeCdrom(fs *fakesys.FakeFileSystem, filepath, contents string) (cdrom *FakeCdrom) {
	cdrom = &FakeCdrom{
		Fs:                fs,
		MediaFilePath:     filepath,
		MediaFileContents: contents,
	}
	return
}

func (cdrom *FakeCdrom) WaitForMedia() (err error) {
	if cdrom.WaitForMediaError != nil {
		err = cdrom.WaitForMediaError
		return
	}

	cdrom.MediaAvailable = true
	return
}

func (cdrom *FakeCdrom) Mount(mountPath string) (err error) {
	switch {
	case !cdrom.MediaAvailable:
		err = errors.New("media not available")
	case cdrom.Mounted:
		err = errors.New("already mounted")
	case cdrom.MountError != nil:
		err = cdrom.MountError
	}
	if err != nil {
		return
	}

	cdrom.MountMountPath = mountPath
	cdrom.Fs.WriteToFile(filepath.Join(mountPath, cdrom.MediaFilePath), cdrom.MediaFileContents)
	cdrom.Mounted = true
	return
}

func (cdrom *FakeCdrom) Unmount() (err error) {
	switch {
	case !cdrom.Mounted:
		err = errors.New("device not mounted")
	case cdrom.UnmountError != nil:
		err = cdrom.UnmountError
	}
	if err != nil {
		return
	}

	cdrom.Fs.RemoveAll(filepath.Join(cdrom.MountMountPath, cdrom.MediaFilePath))
	cdrom.Mounted = false
	return
}

func (cdrom *FakeCdrom) Eject() (err error) {
	switch {
	case cdrom.Mounted:
		err = errors.New("device busy")
	case cdrom.EjectError != nil:
		err = cdrom.EjectError
	}
	if err != nil {
		return
	}

	cdrom.MediaAvailable = false
	return
}
