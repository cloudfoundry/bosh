package fakes

type FakeCopier struct {
	FilteredCopyToTempTempDir string
	FilteredCopyToTempError   error
	FilteredCopyToTempDir     string
	FilteredCopyToTempFilters []string

	CleanUpTempDir string
}

func NewFakeCopier() (copier *FakeCopier) {
	copier = &FakeCopier{}
	return
}

func (c *FakeCopier) FilteredCopyToTemp(dir string, filters []string) (tempDir string, err error) {
	c.FilteredCopyToTempDir = dir
	c.FilteredCopyToTempFilters = filters
	tempDir = c.FilteredCopyToTempTempDir
	err = c.FilteredCopyToTempError
	return
}

func (c *FakeCopier) CleanUp(tempDir string) {
	c.CleanUpTempDir = tempDir
}
