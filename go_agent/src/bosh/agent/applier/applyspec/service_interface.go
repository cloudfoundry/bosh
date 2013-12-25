package applyspec

type V1Service interface {
	Get() (spec V1ApplySpec, err error)
	Set(spec V1ApplySpec) (err error)
}
