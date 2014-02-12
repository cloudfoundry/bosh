package agent_test

import (
	. "bosh/agent"
	fakeaction "bosh/agent/action/fakes"
	boshtask "bosh/agent/task"
	faketask "bosh/agent/task/fakes"
	boshassert "bosh/assert"
	boshhandler "bosh/handler"
	boshlog "bosh/logger"
	"errors"
	"fmt"
	. "github.com/onsi/ginkgo"
	"github.com/stretchr/testify/assert"
)

func getActionDispatcherDependencies() (logger boshlog.Logger, taskService *faketask.FakeService, actionFactory *fakeaction.FakeFactory, actionRunner *fakeaction.FakeRunner) {
	logger = boshlog.NewLogger(boshlog.LEVEL_NONE)
	taskService = &faketask.FakeService{}
	actionFactory = &fakeaction.FakeFactory{}
	actionRunner = &fakeaction.FakeRunner{}
	return
}
func init() {
	Describe("Testing with Ginkgo", func() {
		It("dispatch responds with exception when the method is unknown", func() {
			logger, taskService, actionFactory, actionRunner := getActionDispatcherDependencies()

			req := boshhandler.NewRequest("reply to me", "gibberish", []byte{})

			actionFactory.CreateErr = true

			dispatcher := NewActionDispatcher(logger, taskService, actionFactory, actionRunner)

			resp := dispatcher.Dispatch(req)

			boshassert.MatchesJsonString(GinkgoT(), resp, `{"exception":{"message":"unknown message gibberish"}}`)
			assert.Equal(GinkgoT(), actionFactory.CreateMethod, "gibberish")
		})
		It("dispatch handles synchronous action", func() {

			logger, taskService, actionFactory, actionRunner := getActionDispatcherDependencies()

			actionFactory.CreateAction = &fakeaction.TestAction{
				Asynchronous: false,
			}
			actionRunner.RunValue = "some value"

			dispatcher := NewActionDispatcher(logger, taskService, actionFactory, actionRunner)

			req := boshhandler.NewRequest("reply to me!", "some action", []byte("some payload"))
			resp := dispatcher.Dispatch(req)
			assert.Equal(GinkgoT(), req.Method, actionFactory.CreateMethod)
			assert.Equal(GinkgoT(), req.GetPayload(), actionRunner.RunPayload)
			assert.Equal(GinkgoT(), boshhandler.NewValueResponse("some value"), resp)
		})
		It("dispatch handles synchronous action when err", func() {

			logger, taskService, actionFactory, actionRunner := getActionDispatcherDependencies()

			actionFactory.CreateAction = &fakeaction.TestAction{}
			actionRunner.RunErr = errors.New("some error")

			dispatcher := NewActionDispatcher(logger, taskService, actionFactory, actionRunner)

			req := boshhandler.NewRequest("reply to me!", "some action", []byte("some payload"))
			resp := dispatcher.Dispatch(req)
			expectedJson := fmt.Sprintf("{\"exception\":{\"message\":\"Action Failed %s: some error\"}}", req.Method)
			boshassert.MatchesJsonString(GinkgoT(), resp, expectedJson)
			assert.Equal(GinkgoT(), actionFactory.CreateMethod, "some action")
		})
		It("dispatch handles asynchronous action", func() {

			logger, taskService, actionFactory, actionRunner := getActionDispatcherDependencies()

			taskService.StartTaskStartedTask = boshtask.Task{Id: "found-57-id", State: boshtask.TaskStateDone}
			actionFactory.CreateAction = &fakeaction.TestAction{
				Asynchronous: true,
			}
			actionRunner.RunValue = "some-task-result-value"

			dispatcher := NewActionDispatcher(logger, taskService, actionFactory, actionRunner)
			req := boshhandler.NewRequest("reply to me!", "some async action", []byte("some payload"))
			resp := dispatcher.Dispatch(req)

			boshassert.MatchesJsonString(GinkgoT(), resp, `{"value":{"agent_task_id":"found-57-id","state":"done"}}`)

			value, err := taskService.StartTaskFunc()
			assert.NoError(GinkgoT(), err)
			assert.Equal(GinkgoT(), "some-task-result-value", value)

			assert.Equal(GinkgoT(), req.Method, actionFactory.CreateMethod)
			assert.Equal(GinkgoT(), req.GetPayload(), actionRunner.RunPayload)
			assert.Equal(GinkgoT(), actionFactory.CreateMethod, "some async action")
		})
	})
}
