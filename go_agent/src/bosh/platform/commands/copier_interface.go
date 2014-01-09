package commands

type Copier interface {
	FilteredCopyToTemp(dir string, filters []string) (tempDir string, err error)
	CleanUp(tempDir string)
}
