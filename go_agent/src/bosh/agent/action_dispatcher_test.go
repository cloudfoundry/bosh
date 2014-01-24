package agent

import (
	fakeaction "bosh/agent/action/fakes"
	boshtask "bosh/agent/task"
	faketask "bosh/agent/task/fakes"
	boshassert "bosh/assert"
	boshhandler "bosh/handler"
	boshlog "bosh/logger"
	"errors"
	"fmt"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestDispatchRespondsWithExceptionWhenTheMethodIsUnknown(t *testing.T) {
	logger, taskService, actionFactory, actionRunner := getActionDispatcherDependencies()

	req := boshhandler.NewRequest("reply to me", "gibberish", []byte{})

	actionFactory.CreateErr = true

	dispatcher := NewActionDispatcher(logger, taskService, actionFactory, actionRunner)

	resp := dispatcher.Dispatch(req)

	boshassert.MatchesJsonString(t, resp, `{"exception":{"message":"unknown message gibberish"}}`)
	assert.Equal(t, actionFactory.CreateMethod, "gibberish")
}

func TestDispatchHandlesSynchronousAction(t *testing.T) {
	logger, taskService, actionFactory, actionRunner := getActionDispatcherDependencies()

	// when action is successful
	actionFactory.CreateAction = &fakeaction.TestAction{
		Asynchronous: false,
	}
	actionRunner.RunValue = "some value"

	dispatcher := NewActionDispatcher(logger, taskService, actionFactory, actionRunner)

	req := boshhandler.NewRequest("reply to me!", "some action", []byte("some payload"))
	resp := dispatcher.Dispatch(req)
	assert.Equal(t, req.Method, actionFactory.CreateMethod)
	assert.Equal(t, req.GetPayload(), actionRunner.RunPayload)
	assert.Equal(t, boshhandler.NewValueResponse("some value"), resp)
}

func TestDispatchHandlesSynchronousActionWhenErr(t *testing.T) {
	logger, taskService, actionFactory, actionRunner := getActionDispatcherDependencies()

	// when action returns an error
	actionFactory.CreateAction = &fakeaction.TestAction{}
	actionRunner.RunErr = errors.New("some error")

	dispatcher := NewActionDispatcher(logger, taskService, actionFactory, actionRunner)

	req := boshhandler.NewRequest("reply to me!", "some action", []byte("some payload"))
	resp := dispatcher.Dispatch(req)
	expectedJson := fmt.Sprintf("{\"exception\":{\"message\":\"Action Failed %s: some error\"}}", req.Method)
	boshassert.MatchesJsonString(t, resp, expectedJson)
	assert.Equal(t, actionFactory.CreateMethod, "some action")
}

func TestDispatchHandlesAsynchronousAction(t *testing.T) {
	logger, taskService, actionFactory, actionRunner := getActionDispatcherDependencies()

	taskService.StartTaskStartedTask = boshtask.Task{Id: "found-57-id", State: boshtask.TaskStateDone}
	actionFactory.CreateAction = &fakeaction.TestAction{
		Asynchronous: true,
	}
	actionRunner.RunValue = "some-task-result-value"

	dispatcher := NewActionDispatcher(logger, taskService, actionFactory, actionRunner)
	req := boshhandler.NewRequest("reply to me!", "some async action", []byte("some payload"))
	resp := dispatcher.Dispatch(req)

	boshassert.MatchesJsonString(t, resp, `{"value":{"agent_task_id":"found-57-id","state":"done"}}`)

	value, err := taskService.StartTaskFunc()
	assert.NoError(t, err)
	assert.Equal(t, "some-task-result-value", value)

	assert.Equal(t, req.Method, actionFactory.CreateMethod)
	assert.Equal(t, req.GetPayload(), actionRunner.RunPayload)
	assert.Equal(t, actionFactory.CreateMethod, "some async action")
}

func getActionDispatcherDependencies() (logger boshlog.Logger, taskService *faketask.FakeService, actionFactory *fakeaction.FakeFactory, actionRunner *fakeaction.FakeRunner) {
	logger = boshlog.NewLogger(boshlog.LEVEL_NONE)
	taskService = &faketask.FakeService{}
	actionFactory = &fakeaction.FakeFactory{}
	actionRunner = &fakeaction.FakeRunner{}
	return
}
