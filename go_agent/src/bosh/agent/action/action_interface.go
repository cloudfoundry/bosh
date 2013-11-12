package action

type Action interface {
	Run(args []string) (err error)
}
