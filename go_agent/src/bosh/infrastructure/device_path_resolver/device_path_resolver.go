package device_path_resolver

type DevicePathResolver interface {
	GetRealDevicePath(devicePath string) (realPath string, err error)
}
