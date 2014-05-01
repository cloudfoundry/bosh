package disk

type Mounter interface {
	Mount(partitionPath, mountPoint string, mountOptions ...string) (err error)
	Unmount(partitionOrMountPoint string) (didUnmount bool, err error)

	RemountAsReadonly(mountPoint string) (err error)
	Remount(fromMountPoint, toMountPoint string, mountOptions ...string) (err error)

	SwapOn(partitionPath string) (err error)

	IsMountPoint(path string) (result bool, err error)
	IsMounted(devicePathOrMountPoint string) (result bool, err error)
}
