package drain

import (
	boshas "bosh/agent/applier/applyspec"
)

type updateDrainParams struct {
	oldSpec boshas.V1ApplySpec
	newSpec boshas.V1ApplySpec
}

func NewUpdateDrainParams(oldSpec, newSpec boshas.V1ApplySpec) updateDrainParams {
	return updateDrainParams{
		oldSpec: oldSpec,
		newSpec: newSpec,
	}
}

func (p updateDrainParams) JobChange() string {
	switch {
	case len(p.oldSpec.Jobs()) == 0:
		return "job_new"
	case p.oldSpec.JobSpec.Sha1 == p.newSpec.JobSpec.Sha1:
		return "job_unchanged"
	default:
		return "job_changed"
	}
}

func (p updateDrainParams) HashChange() string {
	switch {
	case p.oldSpec.ConfigurationHash == "":
		return "hash_new"
	case p.oldSpec.ConfigurationHash == p.newSpec.ConfigurationHash:
		return "hash_unchanged"
	default:
		return "hash_changed"
	}
}

func (p updateDrainParams) UpdatedPackages() (pkgs []string) {
	for _, pkg := range p.newSpec.PackageSpecs {
		currentPkg, found := p.oldSpec.PackageSpecs[pkg.Name]
		switch {
		case !found:
			pkgs = append(pkgs, pkg.Name)
		case currentPkg.Sha1 != pkg.Sha1:
			pkgs = append(pkgs, pkg.Name)
		}
	}
	return
}

func (p updateDrainParams) JobState() (string, error) {
	return newPresentedJobState(&p.oldSpec).MarshalToJSONString()
}

func (p updateDrainParams) JobNextState() (string, error) {
	return newPresentedJobState(&p.newSpec).MarshalToJSONString()
}
