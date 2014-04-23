package handler

type HandlerFunc func(req Request) (resp Response)

type Handler interface {
	Run(handlerFunc HandlerFunc) error
	Start(handlerFunc HandlerFunc) error
	Stop()

	RegisterAdditionalHandlerFunc(handlerFunc HandlerFunc)

	SendToHealthManager(topic string, payload interface{}) error
}
