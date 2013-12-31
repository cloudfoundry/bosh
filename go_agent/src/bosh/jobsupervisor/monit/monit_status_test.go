package monit

import (
	boshsysstat "bosh/jobsupervisor/system_status"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestServicesInGroupReturnsSliceOfService(t *testing.T) {
	status := buildMonitStatus()

	services := status.ServicesInGroup("vcap")
	expectedServices := []Service{
		{
			Monitored: true,
			Status:    "running",
		},
		{
			Monitored: false,
			Status:    "unknown",
		},
		{
			Monitored: true,
			Status:    "starting",
		},
		{
			Monitored: true,
			Status:    "failing",
		},
	}
	assert.Equal(t, len(expectedServices), len(services))
	for i, expectedService := range expectedServices {
		assert.Equal(t, expectedService, services[i])
	}
}

func TestSystemStatus(t *testing.T) {
	status := buildMonitStatus()

	systemStatus := status.SystemStatus()

	expectedStatus := boshsysstat.SystemStatus{
		Load: boshsysstat.SystemStatusLoad{
			Avg01: 2.02,
			Avg05: 5.6,
			Avg15: 4.44,
		},
		CPU: boshsysstat.SystemStatusCPU{
			User:   40.90,
			System: 80.70,
		},
		Memory: boshsysstat.SystemStatusMemory{
			Percent:  1.1,
			Kilobyte: 8041492,
		},
		Swap: boshsysstat.SystemStatusSwap{
			Percent:  2.2,
			Kilobyte: 684800,
		},
	}

	assert.Equal(t, systemStatus, expectedStatus)
}

func buildMonitStatus() (status monitStatus) {
	status = monitStatus{
		Services: servicesTag{
			Services: []serviceTag{
				{
					Name:    "running-service",
					Status:  0,
					Monitor: 1,
					Type:    3,
				},
				{
					Name:    "unmonitored-service",
					Status:  0,
					Monitor: 0,
					Type:    3,
				},
				{
					Name:    "starting-service",
					Status:  0,
					Monitor: 2,
					Type:    3,
				},
				{
					Name:    "failing-service",
					Status:  512,
					Monitor: 1,
					Type:    3,
				},
				{
					Name:    "system_test.local",
					Status:  0,
					Monitor: 1,
					Type:    5,
					System: systemTag{
						Load: loadTag{
							Avg01: 2.02,
							Avg05: 5.6,
							Avg15: 4.44,
						},
						CPU: cpuTag{
							User:   40.90,
							System: 80.70,
						},
						Memory: memoryTag{
							Percent:  1.1,
							Kilobyte: 8041492,
						},
						Swap: swapTag{
							Percent:  2.2,
							Kilobyte: 684800,
						},
					},
				},
			},
		},
		ServiceGroups: serviceGroupsTag{
			ServiceGroups: []serviceGroupTag{
				{
					Name: "vcap",
					Services: []string{
						"running-service",
						"unmonitored-service",
						"starting-service",
						"failing-service",
					},
				},
			},
		},
	}
	return
}
