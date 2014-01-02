package monit

type Status interface {
	ServicesInGroup(name string) (services []Service)
}

type Service struct {
	Monitored bool
	Status    string
}
