package applyspec

import (
	boshsettings "bosh/settings"
)

type V1Service interface {
	// Error will only be returned if Set() was used and Get() cannot retrieve saved copy.
	// New empty spec will be returned if Set() was never used.
	Get() (V1ApplySpec, error)

	Set(V1ApplySpec) error

	PopulateDynamicNetworks(V1ApplySpec, boshsettings.Settings) (V1ApplySpec, error)
}
