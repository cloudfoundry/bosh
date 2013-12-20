package mbus

type HandlerFunc func(req Request) (resp Response)

type Handler interface {
	SubscribeToDirector(handlerFunc HandlerFunc) (err error)
	SendToHealthManager(topic string, payload interface{}) (err error)
}
