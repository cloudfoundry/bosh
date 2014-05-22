package drain

import (
	boshas "bosh/agent/applier/applyspec"
)

type staticDrainParams struct {
	jobChange       string
	hashChange      string
	updatedPackages []string

	oldSpec boshas.V1ApplySpec
	newSpec *boshas.V1ApplySpec
}

func NewShutdownDrainParams(
	oldSpec boshas.V1ApplySpec,
	newSpec *boshas.V1ApplySpec,
) staticDrainParams {
	return staticDrainParams{
		jobChange:       "job_shutdown",
		hashChange:      "hash_unchanged",
		updatedPackages: []string{},
		oldSpec:         oldSpec,
		newSpec:         newSpec,
	}
}

func NewStatusDrainParams(
	oldSpec boshas.V1ApplySpec,
	newSpec *boshas.V1ApplySpec,
) staticDrainParams {
	return staticDrainParams{
		jobChange:       "job_check_status",
		hashChange:      "hash_unchanged",
		updatedPackages: []string{},
		oldSpec:         oldSpec,
		newSpec:         newSpec,
	}
}

func (p staticDrainParams) JobChange() (change string)       { return p.jobChange }
func (p staticDrainParams) HashChange() (change string)      { return p.hashChange }
func (p staticDrainParams) UpdatedPackages() (pkgs []string) { return p.updatedPackages }

func (p staticDrainParams) JobState() (string, error) {
	return newPresentedJobState(&p.oldSpec).MarshalToJSONString()
}

func (p staticDrainParams) JobNextState() (string, error) {
	return newPresentedJobState(p.newSpec).MarshalToJSONString()
}
