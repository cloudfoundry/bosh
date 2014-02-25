package aws_device_path_resolver

import (
	bosherr "bosh/errors"
	boshsys "bosh/system"
	"strings"
	"time"
)

type oracle struct {
	diskWaitTimeout time.Duration
	fs              boshsys.FileSystem
}

func New(diskWaitTimeout time.Duration, fs boshsys.FileSystem) (oracle oracle) {
	oracle.fs = fs
	oracle.diskWaitTimeout = diskWaitTimeout
	return
}

func (p oracle) GetRealDevicePath(devicePath string) (realPath string, err error) {
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

func (p oracle) findPossibleDevice(devicePath string) (realPath string, found bool) {
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
