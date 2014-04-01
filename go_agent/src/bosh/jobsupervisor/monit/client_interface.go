package monit

type Client interface {
	ServicesInGroup(name string) (services []string, err error)
	StartService(name string) (err error)
	StopService(name string) (err error)
	UnmonitorService(name string) (err error)
	Status() (status Status, err error)
}
