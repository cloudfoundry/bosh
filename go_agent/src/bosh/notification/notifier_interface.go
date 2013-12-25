package notification

type Notifier interface {
	NotifyShutdown() (err error)
}
