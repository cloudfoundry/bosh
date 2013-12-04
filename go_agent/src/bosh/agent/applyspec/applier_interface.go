package applyspec

type Applier interface {
	Apply(jobs []Job, packages []Package) error
}
