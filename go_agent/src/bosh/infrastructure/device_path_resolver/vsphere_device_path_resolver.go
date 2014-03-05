package device_path_resolver

import (
	boshsys "bosh/system"
	"fmt"
	"path"
	"strings"
	"time"
)

const MAX_SCAN_RETRIES = 30

type vsphereDevicePathResolver struct {
	diskWaitTimeout time.Duration
	fs              boshsys.FileSystem
}

func NewVsphereDevicePathResolver(diskWaitTimeout time.Duration, fs boshsys.FileSystem) (vsphereDevicePathResolver vsphereDevicePathResolver) {
	vsphereDevicePathResolver.fs = fs
	vsphereDevicePathResolver.diskWaitTimeout = diskWaitTimeout
	return
}

func (devicePathResolver vsphereDevicePathResolver) GetRealDevicePath(devicePath string) (realPath string, err error) {
	devicePaths, err := devicePathResolver.fs.Glob("/sys/bus/scsi/devices/*:0:0:0/block/*")
	if err != nil {
		return
	}

	var hostId string

	for _, rootDevicePath := range devicePaths {
		if path.Base(rootDevicePath) == "sda" {
			rootDevicePathSplits := strings.Split(rootDevicePath, "/")
			if len(rootDevicePathSplits) > 5 {
				scsiPath := rootDevicePathSplits[5]
				scsiPathSplits := strings.Split(scsiPath, ":")
				if len(scsiPathSplits) > 0 {
					hostId = scsiPathSplits[0]
				}
			}
		}
	}

	if len(hostId) == 0 {
		return
	}

	scanPath := fmt.Sprintf("/sys/class/scsi_host/host%s/scan", hostId)
	err = devicePathResolver.fs.WriteFileString(scanPath, "- - -")
	if err != nil {
		return
	}

	deviceGlobPath := fmt.Sprintf("/sys/bus/scsi/devices/%s:0:%s:0/block/*", hostId, devicePath)

	for i := 0; i < MAX_SCAN_RETRIES; i++ {
		devicePaths, err = devicePathResolver.fs.Glob(deviceGlobPath)
		if err != nil || len(devicePaths) == 0 {
			time.Sleep(devicePathResolver.diskWaitTimeout)
			continue
		}
	}

	if err != nil || len(devicePaths) == 0 {
		return
	}

	basename := path.Base(devicePaths[0])
	realPath = path.Join("/dev/", basename)

	return
}
