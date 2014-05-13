package syslog

type Msg struct {
	Content string
}

type CallbackFunc func(Msg)

type Server interface {
	Start(CallbackFunc) error
	Stop() error
}
