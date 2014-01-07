package cmd

type Cmd interface {
	Run(args []string) (err error)
}
