package fakes

type FakeMounter struct {
	MountPartitionPaths []string
	MountMountPoints    []string
	MountMountOptions   [][]string

	RemountAsReadonlyPath string

	RemountFromMountPoint string
	RemountToMountPoint   string
	RemountMountOptions   []string

	SwapOnPartitionPaths []string

	UnmountPartitionPath string
	UnmountDidUnmount    bool

	IsMountedDevicePathOrMountPoint string
	IsMountedResult                 bool
}

func (m *FakeMounter) Mount(partitionPath, mountPoint string, mountOptions ...string) (err error) {
	m.MountPartitionPaths = append(m.MountPartitionPaths, partitionPath)
	m.MountMountPoints = append(m.MountMountPoints, mountPoint)
	m.MountMountOptions = append(m.MountMountOptions, mountOptions)
	return
}

func (m *FakeMounter) RemountAsReadonly(mountPoint string) (err error) {
	m.RemountAsReadonlyPath = mountPoint
	return
}

func (m *FakeMounter) Remount(fromMountPoint, toMountPoint string, mountOptions ...string) (err error) {
	m.RemountFromMountPoint = fromMountPoint
	m.RemountToMountPoint = toMountPoint
	m.RemountMountOptions = mountOptions
	return
}

func (m *FakeMounter) SwapOn(partitionPath string) (err error) {
	m.SwapOnPartitionPaths = append(m.SwapOnPartitionPaths, partitionPath)
	return
}

func (m *FakeMounter) Unmount(partitionPath string) (didUnmount bool, err error) {
	m.UnmountPartitionPath = partitionPath
	didUnmount = m.UnmountDidUnmount
	return
}

func (m *FakeMounter) IsMountPoint(path string) (result bool, err error) {
	return
}

func (m *FakeMounter) IsMounted(devicePathOrMountPoint string) (result bool, err error) {
	m.IsMountedDevicePathOrMountPoint = devicePathOrMountPoint
	result = m.IsMountedResult
	return
}
