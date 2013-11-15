package disk

type Mounter interface {
	Mount(partitionPath, mountPoint string) (err error)
	SwapOn(partitionPath string) (err error)
}
