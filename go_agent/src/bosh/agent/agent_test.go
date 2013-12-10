package agent

import (
	fakeaction "bosh/agent/action/fakes"
	boshtask "bosh/agent/task"
	faketask "bosh/agent/task/fakes"
	boshassert "bosh/assert"
	boshlog "bosh/logger"
	boshmbus "bosh/mbus"
	fakembus "bosh/mbus/fakes"
	fakeplatform "bosh/platform/fakes"
	boshstats "bosh/platform/stats"
	fakestats "bosh/platform/stats/fakes"
	boshsettings "bosh/settings"
	fakesettings "bosh/settings/fakes"
	"errors"
	"fmt"
	"github.com/stretchr/testify/assert"
	"testing"
	"time"
)

func TestRunRespondsWithExceptionWhenTheMethodIsUnknown(t *testing.T) {
	req := boshmbus.NewRequest("reply to me", "gibberish", []byte{})

	settings, logger, handler, platform, taskService, actionFactory := getAgentDependencies()

	actionFactory.CreateErr = true

	agent := New(settings, logger, handler, platform, taskService, actionFactory)

	err := agent.Run()
	assert.NoError(t, err)
	assert.True(t, handler.ReceivedRun)

	resp := handler.Func(req)

	boshassert.MatchesJsonString(t, resp, `{"exception":{"message":"unknown message gibberish"}}`)
	assert.Equal(t, actionFactory.CreateMethod, "gibberish")
}

func TestRunHandlesSynchronousAction(t *testing.T) {
	settings, logger, handler, platform, taskService, actionFactory := getAgentDependencies()

	// when action is successful
	actionFactory.CreateAction = &fakeaction.TestAction{
		Asynchronous: false,
		RunValue:     "some value",
	}

	agent := New(settings, logger, handler, platform, taskService, actionFactory)

	err := agent.Run()
	assert.NoError(t, err)
	assert.True(t, handler.ReceivedRun)

	req := boshmbus.NewRequest("reply to me!", "some action", []byte("some payload"))

	resp := handler.Func(req)
	assert.Equal(t, req.Method, actionFactory.CreateMethod)
	assert.Equal(t, req.GetPayload(), actionFactory.CreateAction.RunPayload)
	assert.Equal(t, boshmbus.NewValueResponse("some value"), resp)

	// when action returns an error
	actionFactory.CreateAction = &fakeaction.TestAction{
		RunErr: errors.New("some error"),
	}

	agent = New(settings, logger, handler, platform, taskService, actionFactory)
	agent.Run()

	resp = handler.Func(req)
	expectedJson := fmt.Sprintf("{\"exception\":{\"message\":\"Action Failed %s: some error\"}}", req.Method)
	boshassert.MatchesJsonString(t, resp, expectedJson)
	assert.Equal(t, actionFactory.CreateMethod, "some action")
}

func TestRunHandlesAsynchronousAction(t *testing.T) {
	settings, logger, handler, platform, taskService, actionFactory := getAgentDependencies()

	taskService.StartTaskStartedTask = boshtask.Task{Id: "found-57-id", State: boshtask.TaskStateDone}
	actionFactory.CreateAction = &fakeaction.TestAction{
		Asynchronous: true,
		RunValue:     "some-task-result-value",
	}

	agent := New(settings, logger, handler, platform, taskService, actionFactory)

	err := agent.Run()
	assert.NoError(t, err)
	assert.True(t, handler.ReceivedRun)

	req := boshmbus.NewRequest("reply to me!", "some async action", []byte("some payload"))

	resp := handler.Func(req)
	assert.Equal(t, boshmbus.NewValueResponse(TaskValue{AgentTaskId: "found-57-id", State: boshtask.TaskStateDone}), resp)

	boshassert.MatchesJsonString(t, resp, `{"value":{"agent_task_id":"found-57-id","state":"done"}}`)

	value, err := taskService.StartTaskFunc()
	assert.NoError(t, err)
	assert.Equal(t, "some-task-result-value", value)

	assert.Equal(t, req.Method, actionFactory.CreateMethod)
	assert.Equal(t, req.GetPayload(), actionFactory.CreateAction.RunPayload)
	assert.Equal(t, actionFactory.CreateMethod, "some async action")
}

func TestRunSetsUpHeartbeats(t *testing.T) {
	settings, logger, handler, platform, taskService, actionFactory := getAgentDependencies()
	settings.Disks = boshsettings.Disks{
		System:     "/dev/sda1",
		Ephemeral:  "/dev/sdb",
		Persistent: map[string]string{"vol-xxxx": "/dev/sdf"},
	}

	platform.FakeStatsCollector = &fakestats.FakeStatsCollector{
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

	agent := New(settings, logger, handler, platform, taskService, actionFactory)
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
	settings, logger, handler, platform, taskService, actionFactory := getAgentDependencies()
	settings.Disks = boshsettings.Disks{
		System: "/dev/sda1",
	}

	platform.FakeStatsCollector = &fakestats.FakeStatsCollector{
		DiskStats: map[string]boshstats.DiskStats{
			"/":               boshstats.DiskStats{Used: 25, Total: 100, InodeUsed: 300, InodeTotal: 1000},
			"/var/vcap/data":  boshstats.DiskStats{Used: 5, Total: 100, InodeUsed: 150, InodeTotal: 1000},
			"/var/vcap/store": boshstats.DiskStats{Used: 0, Total: 100, InodeUsed: 0, InodeTotal: 1000},
		},
	}

	agent := New(settings, logger, handler, platform, taskService, actionFactory)
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
	settings *fakesettings.FakeSettingsService,
	logger boshlog.Logger,
	handler *fakembus.FakeHandler,
	platform *fakeplatform.FakePlatform,
	taskService *faketask.FakeService,
	actionFactory *fakeaction.FakeFactory) {

	settings = &fakesettings.FakeSettingsService{}
	logger = boshlog.NewLogger(boshlog.LEVEL_NONE)
	handler = &fakembus.FakeHandler{}
	platform = &fakeplatform.FakePlatform{
		FakeStatsCollector: &fakestats.FakeStatsCollector{},
	}
	taskService = &faketask.FakeService{}
	actionFactory = &fakeaction.FakeFactory{}
	return
}
