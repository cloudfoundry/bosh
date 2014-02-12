package cdrom

type Cdrom interface {
	WaitForMedia() (err error)
}
