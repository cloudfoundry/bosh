package monit

import (
	boshsysstat "bosh/jobsupervisor/system_status"
	"encoding/xml"
)

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
	Name    string   `xml:"name,attr"`
	Status  int      `xml:"status"`
	Monitor int      `xml:"monitor"`
	Type    int      `xml:"type"`

	System systemTag `xml:"system"`
}

type systemTag struct {
	XMLName xml.Name  `xml:"system"`
	Load    loadTag   `xml:"load"`
	CPU     cpuTag    `xml:"cpu"`
	Memory  memoryTag `xml:"memory"`
	Swap    swapTag   `xml:"swap"`
}

type loadTag struct {
	XMLName xml.Name `xml:"load"`
	Avg01   float32  `xml:"avg01"`
	Avg05   float32  `xml:"avg05"`
	Avg15   float32  `xml:"avg15"`
}

type cpuTag struct {
	XMLName xml.Name `xml:"cpu"`
	User    float32  `xml:"user"`
	System  float32  `xml:"system"`
}

type memoryTag struct {
	XMLName  xml.Name `xml:"memory"`
	Percent  float32  `xml:"percent"`
	Kilobyte int      `xml:"kilobyte"`
}

type swapTag struct {
	XMLName  xml.Name `xml:"swap"`
	Percent  float32  `xml:"percent"`
	Kilobyte int      `xml:"kilobyte"`
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

func (status monitStatus) ServicesInGroup(name string) (services []Service) {
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

func (status monitStatus) SystemStatus() (systemStatus boshsysstat.SystemStatus) {
	for _, serviceTag := range status.Services.Services {
		if serviceTag.Type == 5 {
			systemStatus = boshsysstat.SystemStatus{
				Load: boshsysstat.SystemStatusLoad{
					Avg01: serviceTag.System.Load.Avg01,
					Avg05: serviceTag.System.Load.Avg05,
					Avg15: serviceTag.System.Load.Avg15,
				},
				CPU: boshsysstat.SystemStatusCPU{
					User:   serviceTag.System.CPU.User,
					System: serviceTag.System.CPU.System,
				},
				Memory: boshsysstat.SystemStatusMemory{
					Percent:  serviceTag.System.Memory.Percent,
					Kilobyte: serviceTag.System.Memory.Kilobyte,
				},
				Swap: boshsysstat.SystemStatusSwap{
					Percent:  serviceTag.System.Swap.Percent,
					Kilobyte: serviceTag.System.Swap.Kilobyte,
				},
			}
			return
		}
	}
	return
}
