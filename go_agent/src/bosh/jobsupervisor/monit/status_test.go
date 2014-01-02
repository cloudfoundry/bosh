package monit

import (
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

func buildMonitStatus() (stat status) {
	stat = status{
		Services: servicesTag{
			Services: []serviceTag{
				{
					Name:    "running-service",
					Status:  0,
					Monitor: 1,
				},
				{
					Name:    "unmonitored-service",
					Status:  0,
					Monitor: 0,
				},
				{
					Name:    "starting-service",
					Status:  0,
					Monitor: 2,
				},
				{
					Name:    "failing-service",
					Status:  512,
					Monitor: 1,
				},
				{
					Name:    "system_test.local",
					Status:  0,
					Monitor: 1,
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
