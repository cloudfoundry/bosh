package cdrom

type Cdrom interface {
	WaitForMedia() (err error)
	Mount(mountPath string) (err error)
	Unmount() (err error)
	Eject() (err error)
}
