package fakes

type FakeMounter struct {
	MountPartitionPaths  []string
	MountMountPoints     []string
	SwapOnPartitionPaths []string

	UnmountPartitionPath string
	UnmountDidUnmount    bool
}

func (m *FakeMounter) Mount(partitionPath, mountPoint string) (err error) {
	m.MountPartitionPaths = append(m.MountPartitionPaths, partitionPath)
	m.MountMountPoints = append(m.MountMountPoints, mountPoint)
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
