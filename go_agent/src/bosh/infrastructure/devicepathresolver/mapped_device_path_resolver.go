package devicepathresolver

import (
	"strings"
	"time"

	bosherr "bosh/errors"
	boshsys "bosh/system"
)

type mappedDevicePathResolver struct {
	diskWaitTimeout time.Duration
	fs              boshsys.FileSystem
}

func NewMappedDevicePathResolver(
	diskWaitTimeout time.Duration,
	fs boshsys.FileSystem,
) mappedDevicePathResolver {
	return mappedDevicePathResolver{fs: fs, diskWaitTimeout: diskWaitTimeout}
}

func (dpr mappedDevicePathResolver) GetRealDevicePath(devicePath string) (string, error) {
	stopAfter := time.Now().Add(dpr.diskWaitTimeout)

	realPath, found := dpr.findPossibleDevice(devicePath)

	for !found {
		if time.Now().After(stopAfter) {
			return "", bosherr.New("Timed out getting real device path for %s", devicePath)
		}

		time.Sleep(100 * time.Millisecond)

		realPath, found = dpr.findPossibleDevice(devicePath)
	}

	return realPath, nil
}

func (dpr mappedDevicePathResolver) findPossibleDevice(devicePath string) (string, bool) {
	pathSuffix := strings.Split(devicePath, "/dev/sd")[1]

	possiblePrefixes := []string{
		"/dev/xvd", // Xen
		"/dev/vd",  // KVM
		"/dev/sd",
	}

	for _, prefix := range possiblePrefixes {
		path := prefix + pathSuffix
		if dpr.fs.FileExists(path) {
			return path, true
		}
	}

	return "", false
}
