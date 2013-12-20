package monit

import "encoding/xml"

type monitStatus struct {
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

func (s serviceGroupsTag) Get(name string) (group serviceGroupTag, found bool) {
	for _, g := range s.ServiceGroups {
		if g.Name == name {
			group = g
			found = true
			return
		}
	}
	return
}
