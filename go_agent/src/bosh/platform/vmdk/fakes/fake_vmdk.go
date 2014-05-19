package fakes

import (
	"errors"
	"path/filepath"

	fakesys "bosh/system/fakes"
)

type FakeVmdk struct {
	MountError   error
	UnmountError error

	MediaAvailable    bool
	Fs                *fakesys.FakeFileSystem
	MediaFilePath     string
	MediaFileContents string

	MountMountPath string
	Mounted        bool
}

func NewFakeVmdk(fs *fakesys.FakeFileSystem, filepath, contents string) *FakeVmdk {
	return &FakeVmdk{
		Fs:                fs,
		MediaFilePath:     filepath,
		MediaFileContents: contents,
	}
}

func (vmdk *FakeVmdk) Mount(mountPath string) error {
	switch {
	case !vmdk.MediaAvailable:
		return errors.New("media not available")
	case vmdk.Mounted:
		return errors.New("already mounted")
	case vmdk.MountError != nil:
		return vmdk.MountError
	}

	vmdk.MountMountPath = mountPath

	err := vmdk.Fs.WriteFileString(filepath.Join(mountPath, vmdk.MediaFilePath), vmdk.MediaFileContents)
	if err != nil {
		return err
	}

	vmdk.Mounted = true

	return nil
}

func (vmdk *FakeVmdk) Unmount() error {
	switch {
	case !vmdk.Mounted:
		return errors.New("device not mounted")
	case vmdk.UnmountError != nil:
		return vmdk.UnmountError
	}

	err := vmdk.Fs.RemoveAll(filepath.Join(vmdk.MountMountPath, vmdk.MediaFilePath))
	if err != nil {
		return err
	}

	vmdk.Mounted = false

	return nil
}
