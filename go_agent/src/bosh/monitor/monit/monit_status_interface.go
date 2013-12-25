package monit

type MonitStatus interface {
	ServicesInGroup(name string) (services []Service)
}

type Service struct {
	Monitored bool
	Status    string
}
