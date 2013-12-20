package drain

type staticDrainParams struct {
	jobChange       string
	hashChange      string
	updatedPackages []string
}

func NewShutdownDrainParams() (params staticDrainParams) {
	return staticDrainParams{
		jobChange:       "job_shutdown",
		hashChange:      "hash_unchanged",
		updatedPackages: []string{},
	}
}

func NewStatusDrainParams() (params staticDrainParams) {
	return staticDrainParams{
		jobChange:       "job_check_status",
		hashChange:      "hash_unchanged",
		updatedPackages: []string{},
	}
}

func (p staticDrainParams) JobChange() (change string) {
	return p.jobChange
}

func (p staticDrainParams) HashChange() (change string) {
	return p.hashChange
}

func (p staticDrainParams) UpdatedPackages() (pkgs []string) {
	return p.updatedPackages
}
