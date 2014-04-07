package devicepathresolver

type DevicePathResolver interface {
	GetRealDevicePath(devicePath string) (realPath string, err error)
}
