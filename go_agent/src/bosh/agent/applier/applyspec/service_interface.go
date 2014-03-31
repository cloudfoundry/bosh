package applyspec

type V1Service interface {
	// Error will only be returned if Set() was used and Get() cannot retrieve saved copy.
	// New empty spec will be returned if Set() was never used.
	Get() (spec V1ApplySpec, err error)

	Set(spec V1ApplySpec) (err error)
}
