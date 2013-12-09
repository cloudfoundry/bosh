package disk

type Mounter interface {
	Mount(partitionPath, mountPoint string, mountOptions ...string) (err error)
	RemountAsReadonly(mountPoint string) (err error)
	Remount(fromMountPoint, toMountPoint string, mountOptions ...string) (err error)
	SwapOn(partitionPath string) (err error)
	Unmount(partitionPath string) (didUnmount bool, err error)
	IsMountPoint(path string) (result bool, err error)
	IsMounted(devicePathOrMountPoint string) (result bool, err error)
}
