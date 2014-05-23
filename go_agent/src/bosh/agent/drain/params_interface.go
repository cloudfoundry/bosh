package drain

type DrainScriptParams interface {
	JobChange() (change string)
	HashChange() (change string)
	UpdatedPackages() (pkgs []string)

	JobState() (string, error)
	JobNextState() (string, error)
}
