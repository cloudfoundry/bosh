package udevdevice

type UdevDevice interface {
	KickDevice(filePath string)
	Settle() (err error)
	EnsureDeviceReadable(filePath string) (err error)
}
