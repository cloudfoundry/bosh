package drain

type DrainScript interface {
	Exists() bool
	Run(params DrainScriptParams) (value int, err error)
	Path() string
}
