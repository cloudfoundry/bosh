package fakes

type FakeUdevDevice struct {
	KickDeviceFile            string
	Settled                   bool
	EnsureDeviceReadableFile  string
	EnsureDeviceReadableError error
}

func NewFakeUdevDevice() (lowlevel *FakeUdevDevice) {
	lowlevel = &FakeUdevDevice{}
	return
}

func (l *FakeUdevDevice) KickDevice(filePath string) {
	l.KickDeviceFile = filePath
	return
}

func (l *FakeUdevDevice) Settle() (err error) {
	l.Settled = true
	return
}

func (l *FakeUdevDevice) EnsureDeviceReadable(filePath string) (err error) {
	err = l.EnsureDeviceReadableError
	l.EnsureDeviceReadableFile = filePath
	return
}
