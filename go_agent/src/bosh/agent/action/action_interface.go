package action

type Action interface {
	Run(payload string) (err error)
}
