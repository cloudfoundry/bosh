package monit

type Status interface {
	GetIncarnation() (int, error)
	ServicesInGroup(name string) (services []Service)
}

type Service struct {
	Monitored bool
	Status    string
}
