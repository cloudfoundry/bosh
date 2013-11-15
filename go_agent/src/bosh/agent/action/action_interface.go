package action

type Action interface {
	Run(payloadBytes []byte) (value interface{}, err error)
}
