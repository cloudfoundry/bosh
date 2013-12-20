package fakes

type FakeMonitClient struct {
	ServicesInGroupName     string
	ServicesInGroupServices []string
	ServicesInGroupError    error

	StartServiceNames []string
	StartServiceErr   error

	StopServiceNames []string
	StopServiceErr   error
}

func NewFakeMonitClient() (client *FakeMonitClient) {
	client = &FakeMonitClient{}
	return
}

func (c *FakeMonitClient) ServicesInGroup(name string) (services []string, err error) {
	c.ServicesInGroupName = name
	services = c.ServicesInGroupServices
	err = c.ServicesInGroupError
	return
}

func (c *FakeMonitClient) StartService(name string) (err error) {
	c.StartServiceNames = append(c.StartServiceNames, name)
	err = c.StartServiceErr
	return
}

func (c *FakeMonitClient) StopService(name string) (err error) {
	c.StopServiceNames = append(c.StopServiceNames, name)
	err = c.StopServiceErr
	return
}
