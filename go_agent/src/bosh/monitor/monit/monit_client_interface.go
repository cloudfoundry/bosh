package monit

type MonitClient interface {
	ServicesInGroup(name string) (services []string, err error)
	StartService(name string) (err error)
	StopService(name string) (err error)
}
