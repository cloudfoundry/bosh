package action

type Action interface {
	Run(payload []byte) (value interface{}, err error)
}
