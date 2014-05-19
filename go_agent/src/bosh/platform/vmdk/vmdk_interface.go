package vmdk

type Vmdk interface {
	Mount(mountPath string) (err error)
	Unmount() (err error)
}
