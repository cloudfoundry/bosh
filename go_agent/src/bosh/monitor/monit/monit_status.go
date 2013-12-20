package monit

import "encoding/xml"

type monitStatus struct {
	XMLName     xml.Name `xml:"monit"`
	Id          string   `xml:"id,attr"`
	Incarnation string   `xml:"incarnation,attr"`
	Version     string   `xml:"version,attr"`

	Services      []interface{} `xml:"services"`
	ServiceGroups serviceGroups
}

type serviceGroups struct {
	XMLName       xml.Name       `xml:"servicegroups"`
	ServiceGroups []serviceGroup `xml:"servicegroup"`
}

type serviceGroup struct {
	XMLName xml.Name `xml:"servicegroup"`
	Name    string   `xml:"name,attr"`

	Services []string `xml:"service"`
}

func (s serviceGroups) Get(name string) (group serviceGroup, found bool) {
	for _, g := range s.ServiceGroups {
		if g.Name == name {
			group = g
			found = true
			return
		}
	}
	return
}
