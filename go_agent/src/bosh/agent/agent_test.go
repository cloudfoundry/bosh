package agent

import (
	"bosh/mbus"
	testmbus "bosh/mbus/testhelpers"
	"bosh/platform"
	testplatform "bosh/platform/testhelpers"
	"bosh/settings"
	"github.com/stretchr/testify/assert"
	"testing"
	"time"
)

func TestRunHandlesAMessage(t *testing.T) {
	req := mbus.Request{Method: "ping"}
	expectedResp := mbus.Response{Value: "pong"}

	assertResponseForRequest(t, req, expectedResp)
}

func assertResponseForRequest(t *testing.T, req mbus.Request, expectedResp mbus.Response) {
	s, handler, platform := getAgentDependencies()
	agent := New(s, handler, platform)

	err := agent.Run()
	assert.NoError(t, err)
	assert.True(t, handler.ReceivedRun)

	resp := handler.Func(req)

	assert.Equal(t, resp, expectedResp)
}

func TestRunSetsUpHeartbeats(t *testing.T) {
	s, handler, p := getAgentDependencies()
	s.Disks = settings.Disks{
		System:     "/dev/sda1",
		Ephemeral:  "/dev/sdb",
		Persistent: map[string]string{"vol-xxxx": "/dev/sdf"},
	}

	p = &testplatform.FakePlatform{
		CpuLoad:   platform.CpuLoad{One: 1.0, Five: 5.0, Fifteen: 15.0},
		CpuStats:  platform.CpuStats{User: 55, Sys: 44, Wait: 11, Total: 1000},
		MemStats:  platform.MemStats{Used: 40 * 1024 * 1024, Total: 100 * 1024 * 1024},
		SwapStats: platform.MemStats{Used: 10 * 1024 * 1024, Total: 100 * 1024 * 1024},
		DiskStats: map[string]platform.DiskStats{
			"/":               platform.DiskStats{Used: 25, Total: 100, InodeUsed: 300, InodeTotal: 1000},
			"/var/vcap/data":  platform.DiskStats{Used: 5, Total: 100, InodeUsed: 150, InodeTotal: 1000},
			"/var/vcap/store": platform.DiskStats{Used: 0, Total: 100, InodeUsed: 0, InodeTotal: 1000},
		},
	}

	agent := New(s, handler, p)
	agent.heartbeatInterval = time.Millisecond
	err := agent.Run()
	assert.NoError(t, err)

	hb := <-handler.HeartbeatChan

	assert.Equal(t, []string{"1.00", "5.00", "15.00"}, hb.Vitals.CpuLoad)

	assert.Equal(t, mbus.CpuStats{
		User: "5.5",
		Sys:  "4.4",
		Wait: "1.1",
	}, hb.Vitals.Cpu)

	assert.Equal(t, mbus.MemStats{
		Percent: "40",
		Kb:      "40960",
	}, hb.Vitals.UsedMem)

	assert.Equal(t, mbus.MemStats{
		Percent: "10",
		Kb:      "10240",
	}, hb.Vitals.UsedSwap)

	assert.Equal(t, mbus.Disks{
		System:     mbus.DiskStats{Percent: "25", InodePercent: "30"},
		Ephemeral:  mbus.DiskStats{Percent: "5", InodePercent: "15"},
		Persistent: mbus.DiskStats{Percent: "0", InodePercent: "0"},
	}, hb.Vitals.Disks)
}

func TestRunSetsUpHeartbeatsWithoutEphemeralOrPersistentDisk(t *testing.T) {
	s, handler, p := getAgentDependencies()
	s.Disks = settings.Disks{
		System: "/dev/sda1",
	}

	p = &testplatform.FakePlatform{
		DiskStats: map[string]platform.DiskStats{
			"/":               platform.DiskStats{Used: 25, Total: 100, InodeUsed: 300, InodeTotal: 1000},
			"/var/vcap/data":  platform.DiskStats{Used: 5, Total: 100, InodeUsed: 150, InodeTotal: 1000},
			"/var/vcap/store": platform.DiskStats{Used: 0, Total: 100, InodeUsed: 0, InodeTotal: 1000},
		},
	}

	agent := New(s, handler, p)
	agent.heartbeatInterval = time.Millisecond
	err := agent.Run()
	assert.NoError(t, err)

	hb := <-handler.HeartbeatChan

	assert.Equal(t, mbus.Disks{
		System:     mbus.DiskStats{Percent: "25", InodePercent: "30"},
		Ephemeral:  mbus.DiskStats{},
		Persistent: mbus.DiskStats{},
	}, hb.Vitals.Disks)
}

func getAgentDependencies() (s settings.Settings, h *testmbus.FakeHandler, p *testplatform.FakePlatform) {
	s = settings.Settings{}
	h = &testmbus.FakeHandler{}
	p = &testplatform.FakePlatform{}
	return
}
