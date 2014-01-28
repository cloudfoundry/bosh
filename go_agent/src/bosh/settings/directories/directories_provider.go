package directories

import "path/filepath"

type DirectoriesProvider struct {
	baseDir string
}

func NewDirectoriesProvider(baseDir string) (p DirectoriesProvider) {
	p.baseDir = baseDir
	return
}

func (p DirectoriesProvider) BaseDir() string {
	return p.baseDir
}

func (p DirectoriesProvider) EtcDir() string {
	return filepath.Join(p.BaseDir(), "bosh", "etc")
}

func (p DirectoriesProvider) StoreDir() string {
	return filepath.Join(p.BaseDir(), "store")
}

func (p DirectoriesProvider) DataDir() string {
	return filepath.Join(p.BaseDir(), "data")
}

func (p DirectoriesProvider) StoreMigrationDir() string {
	return filepath.Join(p.BaseDir(), "store_migration_target")
}

func (p DirectoriesProvider) PkgDir() string {
	return filepath.Join(p.BaseDir(), "data", "packages")
}

func (p DirectoriesProvider) CompileDir() string {
	return filepath.Join(p.BaseDir(), "data", "compile")
}

func (p DirectoriesProvider) MonitJobsDir() string {
	return filepath.Join(p.BaseDir(), "monit", "job")
}

func (p DirectoriesProvider) JobsDir() string {
	return filepath.Join(p.BaseDir(), "jobs")
}

func (p DirectoriesProvider) MicroStore() string {
	return filepath.Join(p.BaseDir(), "micro_bosh", "data", "cache")
}

func (p DirectoriesProvider) SettingsDir() string {
	return filepath.Join(p.BaseDir(), "bosh", "settings")
}
