package mbus

type HandlerFunc func(req Request) (resp Response)

type Handler interface {
	Run(handlerFunc HandlerFunc) (err error)
}
