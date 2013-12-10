package action

type Action interface {
	IsAsynchronous() bool
	Run(payloadBytes []byte) (value interface{}, err error)
}
