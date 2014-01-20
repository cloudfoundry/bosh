package handler

type HandlerFunc func(req Request) (resp Response)

type Handler interface {
	Run(handlerFunc HandlerFunc) (err error)
	Start(handlerFunc HandlerFunc) (err error)
	Stop()
	SendToHealthManager(topic string, payload interface{}) (err error)
}
