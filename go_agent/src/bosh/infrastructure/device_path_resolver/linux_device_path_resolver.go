package device_path_resolver

import (
	bosherr "bosh/errors"
	boshsys "bosh/system"
	"strings"
	"time"
)

type devicePathResolver struct {
	diskWaitTimeout time.Duration
	fs              boshsys.FileSystem
}

func NewDevicePathResolver(diskWaitTimeout time.Duration, fs boshsys.FileSystem) (awsDevicePathResolver devicePathResolver) {
	awsDevicePathResolver.fs = fs
	awsDevicePathResolver.diskWaitTimeout = diskWaitTimeout
	return
}

func (p devicePathResolver) GetRealDevicePath(devicePath string) (realPath string, err error) {
	stopAfter := time.Now().Add(p.diskWaitTimeout)

	realPath, found := p.findPossibleDevice(devicePath)
	for !found {
		if time.Now().After(stopAfter) {
			err = bosherr.New("Timed out getting real device path for %s", devicePath)
			return
		}
		time.Sleep(100 * time.Millisecond)
		realPath, found = p.findPossibleDevice(devicePath)
	}
	return
}

func (p devicePathResolver) findPossibleDevice(devicePath string) (realPath string, found bool) {
	pathSuffix := strings.Split(devicePath, "/dev/sd")[1]

	possiblePrefixes := []string{"/dev/xvd", "/dev/vd", "/dev/sd"}
	for _, prefix := range possiblePrefixes {
		path := prefix + pathSuffix
		if p.fs.FileExists(path) {
			realPath = path
			found = true
			return
		}
	}
	return
}
