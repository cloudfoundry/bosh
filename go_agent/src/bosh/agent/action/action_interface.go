package action

type Action interface {
	Run(payload []byte) (err error)
}
