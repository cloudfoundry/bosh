package agent

import (
	testaction "bosh/agent/action/testhelpers"
	boshtask "bosh/agent/task"
	testtask "bosh/agent/task/testhelpers"
	boshmbus "bosh/mbus"
	testmbus "bosh/mbus/testhelpers"
	boshstats "bosh/platform/stats"
	teststats "bosh/platform/stats/testhelpers"
	testplatform "bosh/platform/testhelpers"
	boshsettings "bosh/settings"
	"errors"
	"github.com/stretchr/testify/assert"
	"testing"
	"time"
)

func TestRunHandlesAPingMessage(t *testing.T) {
	req := boshmbus.NewRequest("reply to me!", "ping", []byte("some payload"))
	expectedResp := boshmbus.Response{Value: "pong"}

	assertResponseForRequest(t, req, expectedResp)
}

func TestRunHandlesAnApplyMessage(t *testing.T) {
	req := boshmbus.NewRequest("reply to me!", "apply", []byte("some payload"))
	expectedResp := boshmbus.Response{State: "running", AgentTaskId: "some-task-id"}

	assertResponseForRequestWithTask(t, req, expectedResp)
}

func assertResponseForRequest(t *testing.T,
	req boshmbus.Request, expectedResp boshmbus.Response) (taskService *testtask.FakeService, actionFactory *testaction.FakeFactory) {

	settings, handler, platform, taskService, actionFactory := getAgentDependencies()
	actionFactory.CreateAction = &testaction.TestAction{RunErr: errors.New("Some error message")}

	taskService.StartTaskStartedTask = boshtask.Task{
		Id:    "some-task-id",
		State: "running",
	}

	agent := New(settings, handler, platform, taskService, actionFactory)

	err := agent.Run()
	assert.NoError(t, err)
	assert.True(t, handler.ReceivedRun)

	resp := handler.Func(req)

	assert.Equal(t, resp, expectedResp)
	return
}

func assertResponseForRequestWithTask(t *testing.T, req boshmbus.Request, expectedResp boshmbus.Response) {
	taskService, actionFactory := assertResponseForRequest(t, req, expectedResp)

	// Test the task
	err := taskService.StartTaskFunc()
	assert.Error(t, err)
	assert.Equal(t, "Some error message", err.Error())

	// Action is created with request's method
	assert.Equal(t, req.Method, actionFactory.CreateMethod)

	// Action gets run with given payload
	createdAction := actionFactory.CreateAction
	assert.Equal(t, []byte("some payload"), createdAction.RunPayload)
}

func TestRunSetsUpHeartbeats(t *testing.T) {
	settings, handler, platform, taskService, actionFactory := getAgentDependencies()
	settings.Disks = boshsettings.Disks{
		System:     "/dev/sda1",
		Ephemeral:  "/dev/sdb",
		Persistent: map[string]string{"vol-xxxx": "/dev/sdf"},
	}

	platform.FakeStatsCollector = &teststats.FakeStatsCollector{
		CpuLoad:   boshstats.CpuLoad{One: 1.0, Five: 5.0, Fifteen: 15.0},
		CpuStats:  boshstats.CpuStats{User: 55, Sys: 44, Wait: 11, Total: 1000},
		MemStats:  boshstats.MemStats{Used: 40 * 1024 * 1024, Total: 100 * 1024 * 1024},
		SwapStats: boshstats.MemStats{Used: 10 * 1024 * 1024, Total: 100 * 1024 * 1024},
		DiskStats: map[string]boshstats.DiskStats{
			"/":               boshstats.DiskStats{Used: 25, Total: 100, InodeUsed: 300, InodeTotal: 1000},
			"/var/vcap/data":  boshstats.DiskStats{Used: 5, Total: 100, InodeUsed: 150, InodeTotal: 1000},
			"/var/vcap/store": boshstats.DiskStats{Used: 0, Total: 100, InodeUsed: 0, InodeTotal: 1000},
		},
	}

	agent := New(settings, handler, platform, taskService, actionFactory)
	agent.heartbeatInterval = 5 * time.Millisecond
	err := agent.Run()
	assert.NoError(t, err)

	var hb boshmbus.Heartbeat

	select {
	case hb = <-handler.HeartbeatChan:
	case <-time.After(time.Millisecond):
		t.Errorf("Did not receive an initial heartbeat in time")
	}

	select {
	case hb = <-handler.HeartbeatChan:
	case <-time.After(100 * time.Millisecond):
		t.Errorf("Did not receive a second heartbeat in time")
	}

	assert.Equal(t, []string{"1.00", "5.00", "15.00"}, hb.Vitals.CpuLoad)

	assert.Equal(t, boshmbus.CpuStats{
		User: "5.5",
		Sys:  "4.4",
		Wait: "1.1",
	}, hb.Vitals.Cpu)

	assert.Equal(t, boshmbus.MemStats{
		Percent: "40",
		Kb:      "40960",
	}, hb.Vitals.UsedMem)

	assert.Equal(t, boshmbus.MemStats{
		Percent: "10",
		Kb:      "10240",
	}, hb.Vitals.UsedSwap)

	assert.Equal(t, boshmbus.Disks{
		System:     boshmbus.DiskStats{Percent: "25", InodePercent: "30"},
		Ephemeral:  boshmbus.DiskStats{Percent: "5", InodePercent: "15"},
		Persistent: boshmbus.DiskStats{Percent: "0", InodePercent: "0"},
	}, hb.Vitals.Disks)
}

func TestRunSetsUpHeartbeatsWithoutEphemeralOrPersistentDisk(t *testing.T) {
	settings, handler, platform, taskService, actionFactory := getAgentDependencies()
	settings.Disks = boshsettings.Disks{
		System: "/dev/sda1",
	}

	platform.FakeStatsCollector = &teststats.FakeStatsCollector{
		DiskStats: map[string]boshstats.DiskStats{
			"/":               boshstats.DiskStats{Used: 25, Total: 100, InodeUsed: 300, InodeTotal: 1000},
			"/var/vcap/data":  boshstats.DiskStats{Used: 5, Total: 100, InodeUsed: 150, InodeTotal: 1000},
			"/var/vcap/store": boshstats.DiskStats{Used: 0, Total: 100, InodeUsed: 0, InodeTotal: 1000},
		},
	}

	agent := New(settings, handler, platform, taskService, actionFactory)
	agent.heartbeatInterval = time.Millisecond
	err := agent.Run()
	assert.NoError(t, err)

	hb := <-handler.HeartbeatChan

	assert.Equal(t, boshmbus.Disks{
		System:     boshmbus.DiskStats{Percent: "25", InodePercent: "30"},
		Ephemeral:  boshmbus.DiskStats{},
		Persistent: boshmbus.DiskStats{},
	}, hb.Vitals.Disks)
}

func getAgentDependencies() (
	settings boshsettings.Settings,
	handler *testmbus.FakeHandler,
	platform *testplatform.FakePlatform,
	taskService *testtask.FakeService,
	actionFactory *testaction.FakeFactory) {

	settings = boshsettings.Settings{}
	handler = &testmbus.FakeHandler{}
	platform = &testplatform.FakePlatform{
		FakeStatsCollector: &teststats.FakeStatsCollector{},
	}
	taskService = &testtask.FakeService{}
	actionFactory = &testaction.FakeFactory{}
	return
}
