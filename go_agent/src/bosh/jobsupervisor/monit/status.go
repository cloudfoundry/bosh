package monit

import (
	"encoding/xml"
)

type status struct {
	XMLName     xml.Name `xml:"monit"`
	Id          string   `xml:"id,attr"`
	Incarnation string   `xml:"incarnation,attr"`
	Version     string   `xml:"version,attr"`

	Services      servicesTag
	ServiceGroups serviceGroupsTag
}

type servicesTag struct {
	XMLName  xml.Name     `xml:"services"`
	Services []serviceTag `xml:"service"`
}

type serviceTag struct {
	XMLName xml.Name `xml:"service"`
	Name    string   `xml:"name,attr"`
	Status  int      `xml:"status"`
	Monitor int      `xml:"monitor"`
}

type serviceGroupsTag struct {
	XMLName       xml.Name          `xml:"servicegroups"`
	ServiceGroups []serviceGroupTag `xml:"servicegroup"`
}

type serviceGroupTag struct {
	XMLName xml.Name `xml:"servicegroup"`
	Name    string   `xml:"name,attr"`

	Services []string `xml:"service"`
}

func (s serviceTag) StatusString() (status string) {
	switch {
	case s.Monitor == 0:
		status = "unknown"
	case s.Monitor == 2:
		status = "starting"
	case s.Status == 0:
		status = "running"
	default:
		status = "failing"
	}
	return
}

func (t serviceGroupsTag) Get(name string) (group serviceGroupTag, found bool) {
	for _, g := range t.ServiceGroups {
		if g.Name == name {
			group = g
			found = true
			return
		}
	}
	return
}

func (t serviceGroupTag) Contains(name string) bool {
	for _, serviceName := range t.Services {
		if serviceName == name {
			return true
		}
	}
	return false
}

func (status status) ServicesInGroup(name string) (services []Service) {
	services = []Service{}

	serviceGroupTag, found := status.ServiceGroups.Get(name)
	if !found {
		return
	}

	for _, serviceTag := range status.Services.Services {
		if serviceGroupTag.Contains(serviceTag.Name) {
			service := Service{
				Monitored: serviceTag.Monitor > 0,
				Status:    serviceTag.StatusString(),
			}

			services = append(services, service)
		}
	}

	return
}
